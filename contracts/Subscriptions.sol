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

/// @author Keshawn
/// @title Subscription Project
/// @custom:experimental This is an experimental contract.

import "@openzeppelin/contracts/access/Ownable.sol";

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

    SubscriptionData public subscriptionData;

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
    event Subscribed(address indexed user, uint price); 
    event CancelSubscription(address indexed user); 
    event DeleteMembership(address indexed user);
    event PriceUpdate(string indexed name, uint price);
    event SendInvite(address indexed from, address to, ApprovalType approvalType); 
    event ConfirmSubAcctApproval(address indexed potentialSubAcct); 
    event ConfirmSplitAcctApproval(address indexed potentialSubAcct);
    event RejectApproval(address indexed potentialSubAcct); 
    
    mapping(address => bool) public isSubscribed; // Are they subscribed?
    mapping(address => Membership) public memberships; // Represents Memberships
    
    mapping(address subacct => PendingApproval) public pendingApprovals; // Represents Pending Approvals
    mapping(address _sendTo => bool) public sentApproval; // Has the approval been sent?

    //mapping(address subaccount => address mainholder) //Are they a sub account? 

    /// @notice This modifier checks to see if the subscription is active by: 
    /// @notice 1. Makes sure the owner of the contract cannot perform certain functions
    /// @notice 2. Makes sure only the main account holder can perform that certain function
    /// @notice 3. Makes sure that person is subscribed
    modifier isSubscriptionActive() {
        require(owner() != msg.sender, "The owner of this contract cannot perform this action"); 
        require(msg.sender == memberships[msg.sender].mainAcct, "Only the main account holder can execute this operation"); //checks to see if you are the main acct holder
        require(isSubscribed[msg.sender] == true, "Subscription doesn't exist, or it's cancelled"); // checks to see if the subscription exist
                
        Membership storage _membership = memberships[msg.sender]; 
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
    /// @param _from represents the approval
    modifier isApproved(address _from, ApprovalType _approvalType) {
        PendingApproval storage getApproval = pendingApprovals[_from]; 
        
        require(owner() != msg.sender, "The owner of this contract cannot perform this action"); 
        require(getApproval._approvalType == _approvalType, "Wrong Approval Type"); 
        require(getApproval.status == true, "Potential account hasn't approved their account"); 
        _; 
    }

    /// @notice This modifier checks to see if the potential account, which is a possible 
    /// @notice sub account user, already has their own subscription where they are the main holder
    /// @param _sendTo represents who the request is going to
    modifier isPotentialAcctSubscribed(address _sendTo) {
        require(isSubscribed[_sendTo] == false, "You already have an account");
        _; 
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
        require(isSubscribed[msg.sender] == false, "You already have a subscription"); 

        if (memberships[msg.sender].ownedPreviousMembership == false){
            Membership memory _member; 
            _member.mainAcct = msg.sender;  

            memberships[msg.sender] = _member;  
            isSubscribed[msg.sender] = true;
            subscriptionData.subscribers++;

            emit Subscribed(msg.sender, subscriptionData.price);
        }

        else {
            Membership memory _member; 
            _member.mainAcct = msg.sender;  

            memberships[msg.sender] = _member;  
            isSubscribed[msg.sender] = true;

            subscriptionData.cancellations--;
            subscriptionData.subscribers++; 

            emit Subscribed(msg.sender, subscriptionData.price);
    
        }
    } 
    
    /// @notice Unsubscribes membership from subscription 
    /// @notice Tracks subscriptions and cancellations
    function cancel() external isSubscriptionActive  {   
        isSubscribed[msg.sender] = false;
        memberships[msg.sender].ownedPreviousMembership = true; 
        subscriptionData.cancellations++;
        subscriptionData.subscribers--; 

        emit CancelSubscription(msg.sender);
    }

    /// @custom:removefunction I may remove this function 
    /// REMINDER: Test Functionality
    function deleteMembership() external isSubscriptionActive  {
        delete isSubscribed[msg.sender]; 
        emit DeleteMembership(msg.sender);
    }

    /// @dev This function will only allow the owner of the contract to set the subscription price
    /// @param _setPrice Sets a new price for the subscription 
    /// REMINDER: _setPrice cannot be lower than zero
    function changePrice(uint _setPrice) external onlyOwner {
        subscriptionData.price = _setPrice;  
        emit PriceUpdate(name, _setPrice);
    }

    /// @notice This function will send a non fractionalized approval to the potential subaccount 
    /// @param _sendTo Address of the potential subaccount holder (Non-Fractional)
    function sendNonFractionalizedInvitation(address _sendTo) external virtual isSubscriptionActive isPotentialAcctSubscribed(_sendTo)  {
        require(sentApproval[_sendTo] == false, "Invitation was already sent");

        ApprovalType approveType = ApprovalType.NonFractionalApproval;

        PendingApproval memory _pendingapproval = PendingApproval({from: msg.sender, to: _sendTo, status: true, _approvalType: approveType });         
        pendingApprovals[_sendTo] = _pendingapproval; 

        sentApproval[_sendTo] = true; 
                
        emit SendInvite(msg.sender, _sendTo, approveType); 
    }

    /// @notice Ex: A roomate wants to add the roomate to their subscription, 
    /// @notice but they want to split/share the subscription between them
    /// @param _sendTo Address of the potential subaccount holder  (Fractionalized) 
    function sendFractionalizedInvitation(address _sendTo) external virtual isSubscriptionActive isPotentialAcctSubscribed(_sendTo)  {
        require(sentApproval[_sendTo] == false, "Invitation was already sent");

        ApprovalType approveType = ApprovalType.FractionalizedApproval;
         
        PendingApproval memory _pendingapproval = PendingApproval({from: msg.sender, to: _sendTo, status: true, _approvalType: approveType});
        pendingApprovals[_sendTo] = _pendingapproval; 

        sentApproval[_sendTo] = true; 
        
        emit SendInvite(msg.sender, _sendTo, approveType);
    }

    /// @notice Allow users to confirm they have approved a split account or sub account subscription
    /// @param _sendTo represents addr of the pending approval
    /// @param _approvalType represents the approval type (fractional or non-fractional) 
    function confirmApproval(address _sendTo, ApprovalType _approvalType) external virtual {
        require(pendingApprovals[_sendTo].to == msg.sender, "Only allowed for potential subaccount holders"); 
    
        if (_approvalType == ApprovalType.NonFractionalApproval) {
            emit ConfirmSubAcctApproval(msg.sender); 
        }
        
        else if (_approvalType == ApprovalType.FractionalizedApproval) {
            emit ConfirmSplitAcctApproval(msg.sender); 
        }

    }
    

    /// @notice Allows potential sub account holders to reject an approval 
    /// @param _from represents of the pending approval
    function rejectInvitation(address _from) external virtual  {
        require(owner() != msg.sender, "Owner of this contract cannot perform this action"); 
        require(pendingApprovals[_from].to == msg.sender, "Only allowed for potential subaccount holders"); 
        delete pendingApprovals[_from]; 
        emit RejectApproval(msg.sender);
    }

    /// @notice Add split account to membership
    /// @param _splitAcct represents who you want to add to the split account
    /// @param _from represents the pending approval
    function addSplitAcct(address _splitAcct, address _from) public virtual isSubscriptionActive isApproved(_from, ApprovalType.NonFractionalApproval)  {
        Membership storage _membership = memberships[msg.sender]; 
        _membership.splitAccts.push(_splitAcct);
    }

    /// @notice Add sub account to membership
    /// @param _subAcct represents who you want to add to the sub account
    /// @param _from represents the pending approval
    function addSubAcct(address _subAcct, address _from) public virtual isSubscriptionActive isApproved(_from, ApprovalType.FractionalizedApproval)  {
        Membership storage _membership = memberships[msg.sender]; 
        _membership.subAccts.push(_subAcct); 
    }

    // renew a persons membership
    // checks to see if they have a membership
    // makes them pay the subscription fee to renew membership
    function renew() external view {
        require(owner() != msg.sender, "The owner of this contract cannot perform this action"); 
        require(msg.sender == memberships[msg.sender].mainAcct, "Only the main account holder can execute this operation"); //checks to see if you are the main acct holder
        require(isSubscribed[msg.sender] == true, "Subscription doesn't exist, or it's cancelled");        
        //require() some sort of payment from the msg.sender
        // membership.expired = false 
    }
}