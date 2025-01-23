# LendLayer

A decentralized lending platform built on the Stacks blockchain, enabling users to lend and borrow assets using smart contracts.

## Features

- Deposit and borrow STX tokens
- Automated interest rate adjustments
- Real-time liquidation risk monitoring
- Interest claiming for lenders
- Collateral management system
- Liquidation mechanism with bonus incentives

## Technical Stack

- Blockchain: Stacks
- Smart Contract: Clarity
- Frontend: React.js
- Testing: Clarinet

## Smart Contract Functions

### Lending Operations
- `deposit`: Deposit STX into lending pool
- `borrow`: Borrow STX against collateral
- `repay`: Repay borrowed amount with interest
- `claim-interest`: Claim earned interest from deposits
- `get-claimable-interest`: View pending interest earnings

### Collateral Management
- `deposit-collateral`: Lock collateral
- `withdraw-collateral`: Remove collateral
- `get-liquidation-risk`: Check position's liquidation risk
- `liquidate`: Liquidate undercollateralized positions

### Pool Information
- `get-user-deposit`: View deposit amount
- `get-user-borrow`: View borrow details
- `get-pool-details`: View pool statistics
- `get-utilization-rate`: Check pool utilization

### Key Parameters
- Base Interest Rate: 5% (500 basis points)
- Collateral Ratio: 150% (15000 basis points)
- Liquidation Threshold: 130% (13000 basis points)
- Liquidation Bonus: 5% (500 basis points)
- Amounts in micro-STX (1 STX = 1,000,000 micro-STX)

## Development Setup

1. Install Stacks tools:
```bash
npm install -g @stacks/cli
```

2. Clone repository:
```bash
git clone https://github.com/chisompeculiar/lendlayer
cd lendlayer
```

3. Run tests:
```bash
clarinet test
```

## Security Features

- Collateral validation
- Liquidation risk monitoring
- Interest rate stabilization
- Balance verification
- Error handling for failed transactions

## Contributing

1. Fork repository
2. Create feature branch
3. Submit pull request
