# DAO Governance System - Decentralized Investment Fund Management

## Overview

A comprehensive decentralized governance system for CryptoVentures DAO, an investment fund enabling token holders to collectively manage treasury allocations and make investment decisions through on-chain governance.

## Features

### Core Governance Mechanisms
- **Proposal Lifecycle**: Draft → Active → Queued → Executed (with full state tracking)
- **Weighted Voting**: Voting power proportional to token holdings, reducing whale dominance
- **Vote Delegation**: Members can delegate voting power to trusted addresses
- **Quorum Requirements**: Configurable minimum participation based on proposal type
- **Approval Thresholds**: Different approval percentages for different proposal types

### Timelock & Security
- **Configurable Timelocks**: Different execution delays based on proposal risk level
  - Operational Expenses: 1 day
  - Experimental Bets: 3 days
  - High Conviction Investments: 7 days
- **Emergency Cancellation**: Guardian role can cancel proposals during timelock
- **Reentrancy Protection**: Safe external calls using OpenZeppelin standards

### Multi-Tier Treasury Management
- **Fund Allocations**:
  - High-Conviction Investments (75% approval threshold)
  - Experimental Bets (66% approval threshold)
  - Operational Expenses (50% approval threshold)
- **Balance Tracking**: Separate tracking for each fund type
- **Withdrawal Management**: Graceful failure if funds insufficient

### Role-Based Access Control
- **Proposer Role**: Can create proposals (requires minimum stake)
- **Executor Role**: Can queue and execute proposals after timelock
- **Guardian Role**: Emergency functions (pause, cancel)
- **Admin Role**: Configuration changes

### Event Emission
- Comprehensive event logging for all state changes
- Indexed parameters for efficient filtering
- Historical record queryable on-chain

## Setup Instructions

### Prerequisites
- Node.js 16+
- npm or yarn

### Installation

```bash
# Clone the repository
git clone https://github.com/manikantaoruganti/dao-governance-system.git
cd dao-governance-system

# Install dependencies
npm install

# Or using yarn
yarn install
```

### Environment Setup

```bash
# Create .env file
cp .env.example .env

# Configure values in .env
# RPC_URL - Local or remote node endpoint
# DEPLOYER_PRIVATE_KEY - Private key for deployments
```

### Compilation

```bash
# Compile smart contracts
npm run compile
```

### Running Tests

```bash
# Run full test suite
npm run test

# Run with coverage
npx hardhat coverage
```

### Local Development

```bash
# Start local Hardhat node
npm run node

# In another terminal, deploy contracts
npm run deploy

# Seed test data
npm run seed
```

## Usage Examples

### Creating a Proposal

```solidity
// Deposit ETH to get governance stake
dao.depositToTreasury{value: ethers.utils.parseEther("10")}("highConviction");

// Create a proposal
const tx = await dao.createProposal(
    recipient_address,
    ethers.utils.parseEther("5"),
    "Proposal for market research investment",
    0 // ProposalType.HighConviction
);
```

### Voting on a Proposal

```solidity
// Cast a vote (0 = For, 1 = Against, 2 = Abstain)
await dao.vote(proposalId, 0); // Vote For
```

### Delegating Voting Power

```solidity
// Delegate voting power to another address
await dao.delegate(delegate_address);
```

### Executing a Proposal

```solidity
// After voting period ends, queue the proposal
await dao.queueProposal(proposalId);

// After timelock expires, execute
await dao.executeProposal(proposalId);
```

## Architecture

### Smart Contracts

**GovernanceDAO.sol**
- Main governance contract
- Manages proposals, voting, treasury
- Implements all 30 core requirements

### Key Data Structures

```solidity
struct Proposal {
    uint256 id;
    address proposer;
    address recipient;
    uint256 amount;
    string description;
    ProposalType proposalType;
    uint256 startBlock;
    uint256 endBlock;
    uint256 forVotes;
    uint256 againstVotes;
    uint256 abstainVotes;
    uint256 eta; // timelock execution time
    bool canceled;
    bool executed;
    uint256 quorumRequired;
    uint256 approvalThreshold;
}
```

### State Management

- Proposals stored in mapping by ID
- Voting state tracked per proposal per member
- Treasury allocations tracked separately by type
- Delegation mappings for proxy voting

## Core Requirements Implementation

All 30 core requirements are implemented:

1. ✅ Members deposit ETH and receive governance voting power
2. ✅ Create investment proposals with recipient, amount, description
3. ✅ Different proposal types with different thresholds
4. ✅ Cast weighted votes (for, against, abstain)
5. ✅ Delegate voting power revocably
6. ✅ Complete proposal lifecycle management
7. ✅ Approved proposals enter timelock queue
8. ✅ Configurable delays by proposal type
9. ✅ Emergency cancellation during timelock
10. ✅ Only authorized roles can execute
11. ✅ Prevent duplicate execution
12. ✅ One vote per member, no changes
13. ✅ Minimum quorum requirement
14. ✅ Defined voting periods
15. ✅ Multi-tier treasury tracking
16. ✅ Fast-track for operational expenses
17. ✅ Emergency functions via guardian role
18. ✅ Comprehensive event emission
19. ✅ Multiple simultaneous roles
20. ✅ Query voting power without voting
21. ✅ Historical voting records on-chain
22. ✅ Edge case handling (zero votes, ties)
23. ✅ Graceful failure on insufficient funds
24. ✅ Consistent voting power calculation
25. ✅ Automatic delegation inclusion
26. ✅ Minimum stake to propose
27. ✅ Prevent queuing unmet proposals
28. ✅ Enforce timelock correctness
29. ✅ Indexed event parameters
30. ✅ Query proposal state at any time

## Testing

Comprehensive test suite covers:
- Governance mechanics
- Voting and delegation
- Timelock enforcement
- Treasury management
- Access control
- Edge cases
- Event emission

## Gas Optimization

- Optimized storage layout
- Efficient voting power calculations
- Minimal storage reads/writes
- Use of mappings over arrays

## Security Considerations

- Reentrancy guards on state-changing functions
- Input validation on all functions
- Safe external calls using low-level calls
- Access control enforcement
- No hardcoded addresses
- No external dependencies with privileges

## Deployment

```bash
# Deploy to localhost
npm run deploy -- --network localhost

# Deploy to testnet (configure in hardhat.config.ts)
npm run deploy -- --network sepolia
```

## Project Structure

```
dao-governance-system/
├── contracts/
│   └── GovernanceDAO.sol
├── scripts/
│   ├── deploy.ts
│   └── seed.ts
├── test/
│   └── governance.test.ts
├── .env.example
├── hardhat.config.ts
├── package.json
├── tsconfig.json
└── README.md
```

## Future Enhancements

- Multi-signature timelock execution
- Treasury diversification
- Reward distribution mechanism
- On-chain voting analytics
- Governance token creation
- Integration with DeFi protocols

## Contributing

Contributions welcome. Please:
1. Create feature branch
2. Add tests
3. Ensure all tests pass
4. Submit pull request

## License

MIT License - see LICENSE file

## Support

For questions or issues:
- Check existing GitHub issues
- Create new issue with details
- Tag with appropriate label

---

**Built with ❤️ for DeFi Governance**
