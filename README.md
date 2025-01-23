# LendLayer

A decentralized lending platform built on the Stacks blockchain, enabling users to lend and borrow assets using smart contracts.

## Features

- Deposit STX tokens into lending pools
- Borrow assets against collateral
- Automated interest rate calculations
- Collateral management system
- Real-time pool statistics

## Technical Stack

- Blockchain: Stacks
- Smart Contract Language: Clarity
- Frontend: React.js
- Testing: Clarinet

## Smart Contract Functions

### User Operations

- `deposit`: Deposit STX tokens into the lending pool
- `withdraw`: Withdraw deposited tokens
- `borrow`: Borrow tokens against collateral
- `get-user-deposit`: View user's deposited amount
- `get-user-borrow`: View user's borrowed amount
- `get-pool-details`: View pool statistics

### Key Parameters

- Interest Rate: 5% (500 basis points)
- Collateral Ratio: 150% (15000 basis points)
- All amounts in micro-STX (1 STX = 1,000,000 micro-STX)

## Development Setup

1. Install Stacks development tools:
```bash
npm install -g @stacks/cli
```

2. Clone the repository:
```bash
git clone https://github.com/yourusername/lendlayer
cd lendlayer
```

3. Run tests:
```bash
clarinet test
```

## Security Considerations

- Smart contract has been designed with safety checks
- Implements collateral validation
- Includes balance verification
- Uses error handling for failed transactions


## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

