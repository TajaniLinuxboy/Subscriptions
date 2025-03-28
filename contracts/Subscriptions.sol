// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0; 

// Track User Subscriptions 
    // By Addr
// Update Status on Subscripton
    // Enums (Inactive, Active) 
// Cancel Subscription based on status
// Allow users to be notified when a price changed happened on a subscription
    // Create Events


// Allow users to give rating on subscriptions????

// I want this contract to be able to be used by other developers
// to create their own subscriptions
// One contract per Subscription EX: Netflix -> One Subscription

// Subscription name and price is going to be set on initialization of the contract (EX: Netflix, $0.00) 

// Biggest Issue: 
// How do users know they are buying the correct subscription and not some scam?
// I can verify that users are buying the correct subscription through message signature
// Each transaction is signed with a private key, which in returns creates a signature hash
// This signature hash can be used to verify the owner of sed subscription


// Fracationlized Accounts, also called split accounts (splitAcct) represent a roomate to roomate behavior. 
// This means that you want to share the subscription, buy both will split the subscription payment between each other

// NonFractionalized Accounts, also called sub accounts (subAcct) represents a parent adding a child to their membership
// Meaning, they are considered add-ons, and can be set up to require a fee

import "@openzeppelin/contracts/access/Ownable.sol";

/// @author Keshawn
/// @title Subscription Project
/// @custom:experimental This is an experimental contract.

contract Subscription is Ownable { 

    string internal name; 
    uint internal price; 
    uint internal addOnAcctPrice;
    uint internal timeFrame; 
    string[] internal acceptedTokens;
    uint private _subscribers; 
    uint private _cancellations; 

    uint private pendingId; 

    struct SubscriptionData {
        uint price; 
        uint timeframe; 
        uint addOnAcctPrice;
        uint subscribers; 
        uint cancellations;
        string name;
    }

    SubscriptionData internal subscriptionData;

    /// @notice Constructor Initiates Subscription Data Struct
    /// @param _name, _price, _timeframe 
    /// @dev other paramters included default values set by the variables in the beginning 
    constructor(string memory _name, uint _price, uint _timeframe) Ownable(msg.sender) {
       subscriptionData = SubscriptionData(
        _price, 
        block.timestamp + _timeframe, 
        addOnAcctPrice, 
        _subscribers,
         _cancellations, 
         _name
        ); 
    }

    struct Membership {
        uint price; 
        address mainAcct; 
        address[] subAccts;
        address[] splitAccts; 
        bool ownedPreviousMembership;
        bool isExpired;
    }

    struct PendingApproval {
        address from; 
        address to; 
        bool status; 
        ApprovalType _approvalType; 
    }
    
    /// @notice FractionalizedApproval stands for the user who are on the main holder's 
    /// @notice account, and they share the subscription (Fractionalized Ownership) 
    /// @notice NonFractionalApproval stands for users who are on the main holder's
    /// @notice account, and they don't share the subscription (Non-Fractionalized Ownership)
    enum ApprovalType {NonFractionalApproval, FractionalizedApproval}

    event StatusChanged(address indexed user, bool _newStatus, bool _oldStatus);
    event Subscribed(address indexed user, uint _price); 
    event CancelSubscription(address indexed user); 
    event DeleteMembership(address indexed user);
    event PriceUpdate(string indexed _name, uint _price);
    event SendApproval(uint indexed id, address from, address to, ApprovalType approvalType); 
    event ConfirmSubAcctApproval(address indexed potentialSubAcct); 
    event ConfirmSplitAcctApproval(address indexed potentialSubAcct);
    event RejectApproval(address indexed potentialSubAcct); 
    
    mapping(address => bool) public _subscribed; // Are they subscribed?
    mapping(address => Membership) public subscription; // Represents Memberships
    
    mapping(uint id => PendingApproval) internal pendingApprovals; // Represents Pending Approvals
    mapping(address sendTo => bool) internal sentApproval; // Has the approval been sent?

    //mapping(address subaccount => address mainholder) //Are they a sub account? 

    /// @notice This modifier checks to see if the subscription is active by: 
    /// @notice 1. Makes sure the owner of the contract cannot perform certain functions
    /// @notice 2. Makes sure only the main account holder can perform that certain function
    /// @notice 3. Makes sure that person is subscribed
    modifier isSubscriptionActive() {
        require(owner() != msg.sender, "The owner of this contract cannot perform this action"); 
        require(msg.sender == subscription[msg.sender].mainAcct, "Only the main account holder can execute this operation"); //checks to see if you are the main acct holder
        require(_subscribed[msg.sender] == true, "Subscription doesn't exist, or it's cancelled"); // checks to see if the subscription exist
                
        Membership storage _membership = subscription[msg.sender]; 
        if(block.timestamp < subscriptionData.timeframe) {
           _membership.isExpired = true;  
        }

        require(_membership.isExpired == false, "Your membership has expired"); 

        _; 
    }

    /// @notice This modifier checks to see if the pending approval has been approved by: 
    /// @notice 1. Makes sure the owner of the contract cannot perform this action 
    /// @notice 2. Makes sure the approval type is correct (Non-Fractional or Fractional) 
    /// @notice 3. Makes sure the approval has been approved
    /// @param _id represents the id of the approval
    modifier isApproved(uint _id, ApprovalType _approvalType) {
        PendingApproval storage getApproval = pendingApprovals[_id]; 
        
        require(owner() != msg.sender, "The owner of this contract cannot perform this action"); 
        require(getApproval._approvalType == _approvalType, "Wrong Approval Type"); 
        require(getApproval.status == true, "Potential account hasn't approved their account"); 
        _; 
    }

    /// @notice This modifier checks to see if the potential account, which is a possible 
    /// @notice sub account user, already has their own subscription where they are the main holder
    /// @param sendTo represents who the request is going to
    modifier isPotentialAcctSubscribed(address sendTo) {
        require(_subscribed[sendTo] == false, "You already have an account");
        _; 
    }

    /// @return Returns data about subscription 
    function getSubscriptionInfo() external view returns(SubscriptionData memory) {
        return subscriptionData; 
    } 

    /// @return Returns the amount subscribers 
    function getSubscribers() external view returns(uint) {
        return subscriptionData.subscribers; 
    }   

    /// @return Return the amount of cancellations by previous subscribers
    function getCancellations() external view returns(uint) {
        return subscriptionData.cancellations; 
    }     

    /// @notice Allows users to subscribe to the subscription 
    /// REMINDER: Make sure users have enough funds in their wallet
    /// REMINDER: Make sure the function is made payable
    function subscribe() public payable virtual {
        require(owner() != msg.sender, "You cannot perform this action"); 
        require(_subscribed[msg.sender] == false, "You already have a subscription"); 

        if (subscription[msg.sender].ownedPreviousMembership == false){
            Membership memory _member; 
            _member.mainAcct = msg.sender;  
            _member.price = subscriptionData.price; 

            subscription[msg.sender] = _member;  
            _subscribed[msg.sender] = true;
            subscriptionData.subscribers++;

            emit Subscribed(msg.sender, subscriptionData.price);
        }

        else {
            Membership memory _member; 
            _member.mainAcct = msg.sender;  
            _member.price = subscriptionData.price; 

            subscription[msg.sender] = _member;  
            _subscribed[msg.sender] = true;

            subscriptionData.cancellations--;
            subscriptionData.subscribers++; 

            emit Subscribed(msg.sender, subscriptionData.price);
    
        }

    } 
    
    /// @notice Unsubscribes membership from subscription 
    /// @notice Tracks subscriptions and cancellations
    function cancel() external isSubscriptionActive  {   
        _subscribed[msg.sender] = false;
        subscription[msg.sender].ownedPreviousMembership = true; 
        subscriptionData.cancellations++;
        subscriptionData.subscribers--; 

        emit CancelSubscription(msg.sender);
    }

    /// @custom:removefunction I may remove this function 
    /// REMINDER: Test Functionality
    function deleteMembership() external isSubscriptionActive  {
        delete _subscribed[msg.sender]; 
        emit DeleteMembership(msg.sender);
    }

    /// @dev This function will only allow the owner of the contract to set the subscription price
    /// @param _setPrice Sets a new price for the subscription 
    /// REMINDER: _setPrice cannot be lower than zero
    function changePrice(uint _setPrice) external onlyOwner {
        price = _setPrice;  
        emit PriceUpdate(name, _setPrice);
    }

    /// @notice This function will send a non fractionalized approval to the potential subaccount 
    /// @param _sendApprovalTo Address of the potential subaccount holder (Non-Fractional)
    function sendNonFractionalizedInvitation(address _sendApprovalTo) external virtual isSubscriptionActive isPotentialAcctSubscribed(_sendApprovalTo)  {
        require(sentApproval[_sendApprovalTo] == false, "You already sent an approval");

        ApprovalType approveType = ApprovalType.NonFractionalApproval;

        PendingApproval memory _pendingapproval = PendingApproval({from: msg.sender, to: _sendApprovalTo, status: true, _approvalType: approveType });         
        pendingApprovals[pendingId] = _pendingapproval; 
        pendingId++;

        sentApproval[_sendApprovalTo] = true; 
                
        emit SendApproval(pendingId, msg.sender, _sendApprovalTo, approveType); 
    }

    /// @notice Ex: A roomate wants to add the roomate to their subscription, 
    /// @notice but they want to split/share the subscription between them
    /// @param _sendApprovalTo Address of the potential subaccount holder  (Fractionalized) 
    function sendFractionalizedInvitation(address _sendApprovalTo) external virtual isSubscriptionActive isPotentialAcctSubscribed(_sendApprovalTo)  {
        require(sentApproval[_sendApprovalTo] == false, "You were already sent an approval");

        ApprovalType approveType = ApprovalType.FractionalizedApproval;
         
        PendingApproval memory _pendingapproval = PendingApproval({from: msg.sender, to: _sendApprovalTo, status: true, _approvalType: approveType});
        pendingApprovals[pendingId] = _pendingapproval; 
        pendingId++;

        sentApproval[_sendApprovalTo] = true; 
        
        emit SendApproval(pendingId, msg.sender, _sendApprovalTo, approveType);
    }

    /// @notice Allow users to confirm they have approved a split account or sub account subscription
    /// @param _id represents the id of the pending approval
    /// @param _approvalType represents the approval type (fractional or non-fractional) 
    function confirmApproval(uint _id, ApprovalType _approvalType) external virtual {
        require(pendingApprovals[_id].to == msg.sender, "Only allowed for potential subaccount holders"); 
    
        if (_approvalType == ApprovalType.NonFractionalApproval) {
            emit ConfirmSubAcctApproval(msg.sender); 
        }
        
        else if (_approvalType == ApprovalType.FractionalizedApproval) {
            emit ConfirmSplitAcctApproval(msg.sender); 
        }

    }
    

    /// @notice Allows potential sub account holders to reject an approval 
    /// @param _id represents the id of the pending approval
    function rejectInvitation(uint _id) external virtual  {
        require(owner() != msg.sender, "Owner of this contract cannot perform this action"); 
        require(pendingApprovals[_id].to == msg.sender, "Only allowed for potential subaccount holders"); 
        delete pendingApprovals[_id]; 
        emit RejectApproval(msg.sender);
    }

    /// @notice Add split account to membership
    /// @param _splitAcct represents who you want to add to the split account
    /// @param _id represents the id of the pending approval
    function addSplitAcct(address _splitAcct, uint _id) public virtual isSubscriptionActive isApproved(_id, ApprovalType.NonFractionalApproval)  {
        Membership storage _membership = subscription[msg.sender]; 
        _membership.splitAccts.push(_splitAcct);
    }

    /// @notice Add sub account to membership
    /// @param _subAcct represents who you want to add to the sub account
    /// @param _id represents the id of the pending approval
    function addSubAcct(address _subAcct, uint _id) public virtual isSubscriptionActive isApproved(_id, ApprovalType.FractionalizedApproval)  {
        Membership storage _membership = subscription[msg.sender]; 
        _membership.subAccts.push(_subAcct); 
    }

    // renew a persons membership
    // checks to see if they have a membership
    // makes them pay the subscription fee to renew membership
    function renew() external view {
        require(owner() != msg.sender, "The owner of this contract cannot perform this action"); 
        require(msg.sender == subscription[msg.sender].mainAcct, "Only the main account holder can execute this operation"); //checks to see if you are the main acct holder
        require(_subscribed[msg.sender] == true, "Subscription doesn't exist, or it's cancelled");        
        //require() some sort of payment from the msg.sender
        // membership.expired = false 
    }
}