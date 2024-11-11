# Cross-Chain Asset Interoperability Platform

A robust protocol enabling seamless cross-chain asset transfer between Bitcoin and other blockchains via Stacks. This platform provides secure, verifiable, and efficient asset bridging with multi-signature support and real-time price feeds.

## Features

### Core Functionality
- Secure asset locking and unlocking between chains
- Multi-signature transaction support
- Real-time price oracle integration
- Event monitoring and webhooks
- Comprehensive API endpoints

### Security Features
- Multi-signature wallet support (n-of-m signatures)
- Transaction verification and validation
- Custodian management system
- Secure price feeds from trusted sources

### Monitoring & Notifications
- Real-time event tracking
- Webhook notifications for critical events
- Transaction status monitoring
- Price feed monitoring

## Technology Stack

- **Smart Contracts**: Clarity
- **Backend**: Python (FastAPI)
- **Blockchain Clients**: 
  - Bitcoin Core
  - Stacks API
- **Additional Tools**:
  - Price Oracle Integration
  - Webhook System
  - Multi-signature Wallet

## Prerequisites

- Python 3.8+
- Bitcoin Node (fully synced)
- Stacks Node
- Access to price feed APIs
- Required Python packages (see `requirements.txt`)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/your-org/cross-chain-platform.git
cd cross-chain-platform
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Configure environment variables:
```bash
cp .env.example .env
# Edit .env with your configuration
```

4. Deploy smart contracts:
```bash
# Deploy on Stacks network
clarinet deploy contracts/asset_bridge.clar
clarinet deploy contracts/oracle.clar
```

## Configuration

### Environment Variables

```env
# Bitcoin Node Configuration
BTC_RPC_USER=your_rpc_user
BTC_RPC_PASSWORD=your_rpc_password
BTC_RPC_HOST=localhost
BTC_RPC_PORT=8332

# Stacks Node Configuration
STX_API_URL=https://your-stacks-node.com
STX_CONTRACT_ADDRESS=your_contract_address
STX_CONTRACT_NAME=asset_bridge

# Oracle Configuration
PRICE_FEED_API_KEY=your_api_key
PRICE_UPDATE_INTERVAL=300

# Webhook Configuration
WEBHOOK_SECRET=your_webhook_secret
```

### Multi-signature Setup

1. Generate required number of key pairs
2. Configure minimum required signatures
3. Add custodians to the contract
4. Initialize multi-signature wallet

## Usage

### Starting the Server

```bash
uvicorn src.api.server:app --reload
```

### API Endpoints

#### Lock BTC
```bash
POST /bridge/lock
{
    "btc_tx_hash": "your_tx_hash",
    "recipient_address": "recipient_stx_address",
    "amount": 1.0
}
```

#### Register Webhook
```bash
POST /webhooks
{
    "url": "https://your-webhook-endpoint.com",
    "events": ["btc_locked", "btc_released", "error"]
}
```

### Monitoring Events

1. Events are emitted for all significant actions
2. Monitor through:
   - Webhook notifications
   - Contract events
   - API endpoints

## Security Considerations

1. **Multi-signature Requirements**
   - Minimum required signatures: 2
   - Total signers: 3
   - All custodians must be verified

2. **Transaction Verification**
   - Minimum confirmations: 6
   - Price validation required
   - Multi-signature verification

3. **Oracle Security**
   - Regular price updates
   - Multiple source verification
   - Timestamp validation

## Development

### Running Tests
```bash
pytest tests/
```

### Creating New Features
1. Create feature branch
2. Implement changes
3. Add tests
4. Submit pull request

## Troubleshooting

### Common Issues

1. **Transaction Verification Failed**
   - Check Bitcoin node synchronization
   - Verify transaction confirmations
   - Check RPC connection

2. **Price Feed Issues**
   - Verify API key
   - Check network connectivity
   - Confirm update interval

3. **Multi-signature Errors**
   - Verify custodian permissions
   - Check signature count
   - Validate transaction format

## Contributing

1. Fork the repository
2. Create feature branch
3. Commit changes
4. Submit pull request

## License

MIT License - see LICENSE file for details

## Contact

- Project Maintainer: [Your Name]
- Email: [Your Email]
- Issue Tracker: GitHub Issues

## Acknowledgments

- Bitcoin Core Team
- Stacks Foundation
- Contributors and testers