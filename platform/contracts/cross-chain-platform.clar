# Project Structure (Updated)
.
├── README.md
├── contracts/
│   ├── asset_bridge.clar
│   ├── vault.clar
│   ├── governance.clar
│   └── oracle.clar
├── src/
│   ├── bitcoin/
│   │   ├── __init__.py
│   │   ├── btc_client.py
│   │   └── multisig.py
│   ├── stacks/
│   │   ├── __init__.py
│   │   ├── stx_client.py
│   │   └── events.py
│   ├── oracle/
│   │   ├── __init__.py
│   │   └── price_feed.py
│   └── api/
│       ├── __init__.py
│       ├── server.py
│       └── webhooks.py
└── tests/
    ├── test_bridge.py
    ├── test_multisig.py
    └── test_oracle.py

# contracts/asset_bridge.clar (Updated)
```clarity
;; Enhanced Asset Bridge Contract with Multi-sig and Oracle Support
(define-data-var bridge-admin principal tx-sender)
(define-data-var min-signatures uint u2)
(define-data-var oracle-address principal 'SP000...)

;; Custodian tracking
(define-map custodians principal bool)
(define-data-var custodian-count uint u0)

;; Enhanced asset tracking with multi-sig support
(define-map wrapped-assets 
    { btc-tx: (buff 32) }
    { amount: uint,
      recipient: principal,
      status: (string-ascii 20),
      signatures: (list 10 principal),
      oracle-price: uint,
      timestamp: uint })

;; Events for better tracking
(define-public (emit-asset-locked (tx-hash (buff 32)) (amount uint))
    (print { event: "asset-locked", tx-hash: tx-hash, amount: amount }))

(define-public (emit-asset-released (tx-hash (buff 32)))
    (print { event: "asset-released", tx-hash: tx-hash }))

;; Multi-sig support
(define-public (add-custodian (new-custodian principal))
    (begin
        (asserts! (is-eq tx-sender (var-get bridge-admin)) (err u1))
        (asserts! (is-none (map-get? custodians new-custodian)) (err u2))
        (map-set custodians new-custodian true)
        (var-set custodian-count (+ (var-get custodian-count) u1))
        (ok true)))

(define-public (lock-btc (tx-hash (buff 32)) (amount uint) (recipient principal) (price uint))
    (let ((signatures (list tx-sender)))
        (begin
            (asserts! (map-get? custodians tx-sender) (err u3))
            (asserts! (> amount u0) (err u4))
            (map-set wrapped-assets
                { btc-tx: tx-hash }
                { amount: amount,
                  recipient: recipient,
                  status: "pending",
                  signatures: signatures,
                  oracle-price: price,
                  timestamp: block-height })
            (emit-asset-locked tx-hash amount)
            (ok true))))

(define-public (sign-lock (tx-hash (buff 32)))
    (let ((asset (unwrap! (map-get? wrapped-assets { btc-tx: tx-hash })
                         (err u5)))
          (current-signatures (get signatures asset)))
        (begin
            (asserts! (map-get? custodians tx-sender) (err u6))
            (asserts! (is-none (index-of current-signatures tx-sender)) (err u7))
            (asserts! (< (len current-signatures) (var-get min-signatures)) (err u8))
            
            (let ((new-signatures (unwrap! (as-max-len? 
                                            (append current-signatures tx-sender)
                                            u10)
                                         (err u9))))
                (if (>= (len new-signatures) (var-get min-signatures))
                    (map-set wrapped-assets
                        { btc-tx: tx-hash }
                        (merge asset { 
                            status: "locked",
                            signatures: new-signatures }))
                    (map-set wrapped-assets
                        { btc-tx: tx-hash }
                        (merge asset {
                            signatures: new-signatures })))
                (ok true)))))
```

# contracts/oracle.clar
```clarity
;; Price Oracle Contract
(define-data-var oracle-admin principal tx-sender)
(define-map price-feeds
    { asset: (string-ascii 10) }
    { price: uint,
      timestamp: uint,
      verified: bool })

(define-public (update-price (asset (string-ascii 10)) (price uint))
    (begin
        (asserts! (is-eq tx-sender (var-get oracle-admin)) (err u1))
        (map-set price-feeds
            { asset: asset }
            { price: price,
              timestamp: block-height,
              verified: true })
        (ok true)))

(define-read-only (get-price (asset (string-ascii 10)))
    (map-get? price-feeds { asset: asset }))
```

# src/bitcoin/multisig.py
```python
from typing import List
import bitcoinutils
from bitcoinutils.keys import PrivateKey, P2pkhAddress
from bitcoinutils.script import Script
from bitcoinutils.transactions import Transaction, TxInput, TxOutput

class MultisigWallet:
    def __init__(self, required_signatures: int, total_signers: int):
        self.required_signatures = required_signatures
        self.total_signers = total_signers
        self.signers: List[PrivateKey] = []
        
    def add_signer(self, private_key: str):
        """Add a signer to the multisig wallet."""
        if len(self.signers) >= self.total_signers:
            raise ValueError("Maximum number of signers reached")
            
        pk = PrivateKey(private_key)
        self.signers.append(pk)
        
    def create_multisig_address(self) -> str:
        """Create a P2SH multisig address."""
        public_keys = [pk.get_public_key().to_hex() for pk in self.signers]
        redeem_script = Script(f"OP_{self.required_signatures} " + 
                             " ".join(public_keys) +
                             f" OP_{self.total_signers} OP_CHECKMULTISIG")
        
        return redeem_script.to_p2sh_address()
        
    def sign_transaction(self, tx_hex: str, input_index: int, signer_index: int) -> str:
        """Sign a transaction with a specific signer."""
        if signer_index >= len(self.signers):
            raise ValueError("Invalid signer index")
            
        tx = Transaction.from_hex(tx_hex)
        signature = self.signers[signer_index].sign_input(
            tx,
            input_index,
            Script(f"OP_{self.required_signatures} " +
                  " ".join([pk.get_public_key().to_hex() for pk in self.signers]) +
                  f" OP_{self.total_signers} OP_CHECKMULTISIG")
        )
        
        return tx.serialize()
```

# src/oracle/price_feed.py
```python
import asyncio
import aiohttp
from typing import Dict, Optional
from datetime import datetime

class PriceFeed:
    def __init__(self, api_key: str, update_interval: int = 300):
        self.api_key = api_key
        self.update_interval = update_interval
        self.prices: Dict[str, float] = {}
        self.last_update: Optional[datetime] = None
        
    async def start(self):
        """Start the price feed update loop."""
        while True:
            await self.update_prices()
            await asyncio.sleep(self.update_interval)
            
    async def update_prices(self):
        """Update asset prices from external sources."""
        async with aiohttp.ClientSession() as session:
            async with session.get(
                f"https://api.coingecko.com/v3/simple/price",
                params={
                    "ids": "bitcoin",
                    "vs_currencies": "usd",
                    "api_key": self.api_key
                }
            ) as response:
                if response.status == 200:
                    data = await response.json()
                    self.prices["BTC"] = data["bitcoin"]["usd"]
                    self.last_update = datetime.now()
                    
    def get_price(self, asset: str) -> Optional[float]:
        """Get the latest price for an asset."""
        return self.prices.get(asset)
```

# src/api/webhooks.py
```python
from fastapi import APIRouter, BackgroundTasks
from pydantic import BaseModel
from typing import Dict, Any
import aiohttp
import json

router = APIRouter()

class WebhookConfig(BaseModel):
    url: str
    events: list[str]
    
class WebhookManager:
    def __init__(self):
        self.webhooks: Dict[str, WebhookConfig] = {}
        
    async def trigger_webhook(
        self,
        event: str,
        data: Dict[str, Any]
    ):
        """Trigger webhooks for a specific event."""
        for webhook_id, config in self.webhooks.items():
            if event in config.events:
                try:
                    async with aiohttp.ClientSession() as session:
                        await session.post(
                            config.url,
                            json={
                                "event": event,
                                "data": data,
                                "timestamp": datetime.now().isoformat()
                            }
                        )
                except Exception as e:
                    print(f"Webhook delivery failed: {str(e)}")
                    
webhook_manager = WebhookManager()

@router.post("/webhooks")
async def register_webhook(config: WebhookConfig):
    """Register a new webhook."""
    webhook_id = f"wh_{len(webhook_manager.webhooks) + 1}"
    webhook_manager.webhooks[webhook_id] = config
    return {"id": webhook_id, "status": "registered"}
```

# src/api/server.py (Updated)
```python
from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
from ..bitcoin.btc_client import BitcoinClient
from ..bitcoin.multisig import MultisigWallet
from ..stacks.stx_client import StacksClient
from ..oracle.price_feed import PriceFeed
from .webhooks import webhook_manager

app = FastAPI()

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize components
price_feed = PriceFeed(api_key="your_api_key")
multisig_wallet = MultisigWallet(required_signatures=2, total_signers=3)

@app.post("/bridge/lock")
async def lock_btc(request: BridgeRequest, background_tasks: BackgroundTasks):
    """Enhanced lock BTC endpoint with multi-sig and price oracle support."""
    try:
        # Verify Bitcoin transaction
        btc_client = BitcoinClient(
            rpc_user="your_rpc_user",
            rpc_password="your_rpc_password"
        )
        tx_verification = btc_client.verify_transaction(request.btc_tx_hash)
        
        if not tx_verification["verified"]:
            raise HTTPException(
                status_code=400,
                detail="Transaction not confirmed"
            )
            
        # Get current BTC price
        btc_price = price_feed.get_price("BTC")
        if not btc_price:
            raise HTTPException(
                status_code=500,
                detail="Price feed unavailable"
            )
            
        # Initialize multi-sig transaction
        stx_client = StacksClient(
            api_url="your_api_url",
            contract_address="your_contract_address",
            contract_name="asset_bridge"
        )
        
        lock_result = await stx_client.lock_btc(
            request.btc_tx_hash,
            request.amount,
            request.recipient_address,
            int(btc_price * 100)  # Convert to integer with 2 decimal places
        )
        
        # Trigger webhook for lock event
        background_tasks.add_task(
            webhook_manager.trigger_webhook,
            "btc_locked",
            {
                "tx_hash": request.btc_tx_hash,
                "amount": request.amount,
                "price": btc_price
            }
        )
        
        return {
            "status": "success",
            "lock_txid": lock_result["txid"],
            "details": lock_result,
            "price": btc_price
        }
        
    except Exception as e:
        # Trigger webhook for error event
        background_tasks.add_task(
            webhook_manager.trigger_webhook,
            "error",
            {"error": str(e)}
        )
        raise HTTPException(
            status_code=500,
            detail=str(e)
        )
```