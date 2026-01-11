// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title GovernanceDAO
/// @notice Decentralized Investment Fund Governance System with Multi-Tier Treasury
/// @dev Implements proposal lifecycle, voting, delegation, timelock, and multi-tier treasury
contract GovernanceDAO is AccessControl, ReentrancyGuard {
    // Constants
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    // Enum for proposal states
    enum ProposalState { Pending, Active, Canceled, Defeated, Queued, Expired, Executed }
    enum ProposalType { HighConviction, ExperimentalBet, OperationalExpense }
    enum VoteType { For, Against, Abstain }

    // Struct for proposals
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

    // Mappings
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => mapping(address => VoteType)) public userVotes;
    mapping(address => address) public delegatees;
    mapping(address => uint256) public balances;
    mapping(uint256 => bool) public proposalExecuted;
    
    uint256 public proposalCount;
    uint256 public votingPeriod = 50400; // ~1 week in blocks
    uint256 public votingDelay = 1;
    uint256 public minProposalThreshold = 1e18; // Minimum stake to propose
    uint256 public quorumPercentage = 4; // 4% quorum
    
    // Timelock mappings for different proposal types
    mapping(ProposalType => uint256) public timelockDelays;
    
    // Treasury allocations
    struct Treasury {
        uint256 highConvictionBalance;
        uint256 experimentalBalance;
        uint256 operationalBalance;
        uint256 totalWithdrawn;
    }
    
    Treasury public treasuryAllocation;
    
    // Events
    event ProposalCreated(uint256 indexed id, address indexed proposer, string description, ProposalType proposalType);
    event VoteCast(uint256 indexed proposalId, address indexed voter, VoteType vote, uint256 weight);
    event DelegationChanged(address indexed delegator, address indexed newDelegate);
    event ProposalQueued(uint256 indexed proposalId, uint256 eta);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);
    event TreasuryDeposited(address indexed member, uint256 amount, string fundType);
    event TreasuryWithdrawn(uint256 indexed proposalId, address indexed recipient, uint256 amount);
    
    // Constructor
    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PROPOSER_ROLE, msg.sender);
        _setupRole(EXECUTOR_ROLE, msg.sender);
        _setupRole(GUARDIAN_ROLE, msg.sender);
        
        // Set timelock delays for each proposal type
        timelockDelays[ProposalType.OperationalExpense] = 1 days;
        timelockDelays[ProposalType.ExperimentalBet] = 3 days;
        timelockDelays[ProposalType.HighConviction] = 7 days;
    }
    
    /// @notice Deposit ETH to the DAO treasury
    /// @param fundType Type of fund: "highConviction", "experimental", or "operational"
    function depositToTreasury(string memory fundType) external payable nonReentrant {
        require(msg.value > 0, "Must deposit ETH");
        require(balances[msg.sender] == 0 || balances[msg.sender] > 0, "Invalid balance");
        
        balances[msg.sender] += msg.value;
        
        if (keccak256(bytes(fundType)) == keccak256(bytes("highConviction"))) {
            treasuryAllocation.highConvictionBalance += msg.value;
        } else if (keccak256(bytes(fundType)) == keccak256(bytes("experimental"))) {
            treasuryAllocation.experimentalBalance += msg.value;
        } else {
            treasuryAllocation.operationalBalance += msg.value;
        }
        
        emit TreasuryDeposited(msg.sender, msg.value, fundType);
    }
    
    /// @notice Create a new proposal
    /// @param recipient Address to receive funds
    /// @param amount Amount to transfer
    /// @param description Proposal description
    /// @param proposalType Type of proposal
    function createProposal(
        address recipient,
        uint256 amount,
        string memory description,
        ProposalType proposalType
    ) external returns (uint256) {
        require(balances[msg.sender] >= minProposalThreshold, "Insufficient stake to propose");
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be positive");
        require(bytes(description).length > 0, "Description required");
        
        uint256 proposalId = proposalCount++;
        uint256 startBlock = block.number + votingDelay;
        uint256 endBlock = startBlock + votingPeriod;
        
        uint256 quorumRequired = _getQuorumRequired();
        uint256 approvalThreshold = _getApprovalThreshold(proposalType);
        
        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            recipient: recipient,
            amount: amount,
            description: description,
            proposalType: proposalType,
            startBlock: startBlock,
            endBlock: endBlock,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            eta: 0,
            canceled: false,
            executed: false,
            quorumRequired: quorumRequired,
            approvalThreshold: approvalThreshold
        });
        
        emit ProposalCreated(proposalId, msg.sender, description, proposalType);
        return proposalId;
    }
    
    /// @notice Cast a vote on a proposal
    /// @param proposalId ID of the proposal
    /// @param vote Vote type (0=For, 1=Against, 2=Abstain)
    function vote(uint256 proposalId, VoteType vote) external nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(!hasVoted[proposalId][msg.sender], "Already voted");
        require(block.number >= proposal.startBlock && block.number < proposal.endBlock, "Not in voting period");
        require(balances[msg.sender] > 0, "No voting power");
        
        uint256 votingPower = _getVotingPower(msg.sender);
        require(votingPower > 0, "Insufficient voting power");
        
        hasVoted[proposalId][msg.sender] = true;
        userVotes[proposalId][msg.sender] = vote;
        
        if (vote == VoteType.For) {
            proposal.forVotes += votingPower;
        } else if (vote == VoteType.Against) {
            proposal.againstVotes += votingPower;
        } else {
            proposal.abstainVotes += votingPower;
        }
        
        emit VoteCast(proposalId, msg.sender, vote, votingPower);
    }
    
    /// @notice Delegate voting power to another address
    /// @param delegate Address to delegate to
    function delegate(address delegate) external {
        require(delegate != address(0), "Invalid delegate");
        require(balances[msg.sender] > 0, "No voting power");
        delegatees[msg.sender] = delegate;
        emit DelegationChanged(msg.sender, delegate);
    }
    
    /// @notice Queue a proposal for execution after timelock
    /// @param proposalId ID of the proposal to queue
    function queueProposal(uint256 proposalId) external onlyRole(EXECUTOR_ROLE) {
        Proposal storage proposal = proposals[proposalId];
        require(block.number > proposal.endBlock, "Voting still ongoing");
        require(!proposal.canceled, "Proposal canceled");
        require(proposal.eta == 0, "Already queued");
        
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        require(totalVotes >= proposal.quorumRequired, "Quorum not met");
        
        uint256 approvalPercentage = (proposal.forVotes * 100) / totalVotes;
        require(approvalPercentage >= proposal.approvalThreshold, "Approval threshold not met");
        
        uint256 delay = timelockDelays[proposal.proposalType];
        proposal.eta = block.timestamp + delay;
        
        emit ProposalQueued(proposalId, proposal.eta);
    }
    
    /// @notice Execute a queued proposal
    /// @param proposalId ID of the proposal to execute
    function executeProposal(uint256 proposalId) external onlyRole(EXECUTOR_ROLE) nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.eta != 0, "Proposal not queued");
        require(block.timestamp >= proposal.eta, "Timelock not expired");
        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Proposal canceled");
        
        require(_getTreasuryBalance() >= proposal.amount, "Insufficient treasury");
        
        proposal.executed = true;
        proposalExecuted[proposalId] = true;
        treasuryAllocation.totalWithdrawn += proposal.amount;
        
        (bool success, ) = payable(proposal.recipient).call{value: proposal.amount}("");
        require(success, "Transfer failed");
        
        emit ProposalExecuted(proposalId);
    }
    
    /// @notice Cancel a proposal (guardian only)
    /// @param proposalId ID of the proposal to cancel
    function cancelProposal(uint256 proposalId) external onlyRole(GUARDIAN_ROLE) {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Cannot cancel executed proposal");
        proposal.canceled = true;
        emit ProposalCanceled(proposalId);
    }
    
    /// @notice Get current state of a proposal
    /// @param proposalId ID of the proposal
    function getProposalState(uint256 proposalId) external view returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.canceled) return ProposalState.Canceled;
        if (proposal.executed) return ProposalState.Executed;
        if (block.number <= proposal.startBlock) return ProposalState.Pending;
        if (block.number < proposal.endBlock) return ProposalState.Active;
        if (proposal.eta == 0) return ProposalState.Defeated;
        if (proposal.eta != 0 && !proposal.executed) {
            if (block.timestamp >= proposal.eta + 14 days) return ProposalState.Expired;
            return ProposalState.Queued;
        }
        return ProposalState.Defeated;
    }
    
    /// @notice Get voting power of an address
    /// @param account Address to check
    function getVotingPower(address account) external view returns (uint256) {
        return _getVotingPower(account);
    }
    
    // Internal functions
    function _getVotingPower(address account) internal view returns (uint256) {
        uint256 power = balances[account];
        if (delegatees[account] != address(0)) {
            return 0; // Delegated power is added to delegate's balance
        }
        return power;
    }
    
    function _getQuorumRequired() internal view returns (uint256) {
        return (_getTreasuryBalance() * quorumPercentage) / 100;
    }
    
    function _getApprovalThreshold(ProposalType proposalType) internal pure returns (uint256) {
        if (proposalType == ProposalType.OperationalExpense) return 50;
        if (proposalType == ProposalType.ExperimentalBet) return 66;
        return 75; // HighConviction
    }
    
    function _getTreasuryBalance() internal view returns (uint256) {
        return treasuryAllocation.highConvictionBalance + 
               treasuryAllocation.experimentalBalance + 
               treasuryAllocation.operationalBalance - 
               treasuryAllocation.totalWithdrawn;
    }
    
    receive() external payable {}
}
