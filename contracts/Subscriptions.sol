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
        mapping(address => SubAccount) children;
        bool ownedPreviousMembership;
        bool isExpired;
    }

    struct SubAccount {
        address parentAccount;
        address subAccount;
        RequestType subAccountType;
    }

    struct PendingRequest {
        address from; 
        address to; 
        bool status; 
        RequestType requestType; 
    }
    
    /// @notice FractionalizedApproval stands for the user who are on the main holder's 
    /// @notice account, and they share the subscription (Fractionalized Ownership) 
    /// @notice NonFractionalApproval stands for users who are on the main holder's
    /// @notice account, and they don't share the subscription (Non-Fractionalized Ownership)
    enum RequestType {NonFractionalApproval, FractionalizedApproval}

    event StatusChanged(address indexed account, bool _newStatus, bool _oldStatus);
    event Subscribed(address indexed account, uint price); 
    event CancelSubscription(address indexed account); 
    event DeleteMembership(address indexed account);
    event PriceUpdate(string indexed name, uint price);
    event SendInvite(address indexed from, address to, RequestType _requestType); 
    event ConfirmRequest(address indexed from);
    event RejectRequest(address indexed account); 
    event AddedToMembership(address indexed parentAccount, address account);

    ///@custom:errors Custom Errors
    error OwnerNotAllowed(address owner); 
    error MainAcctOnly();
    error MembershipDoesntExists(address account);      
    error MembershipExpired(address account);
    error IncorrectApprovalType(RequestType _requestType); 
    error NotApproved(); 
    error MembershipAlreadyExists(address account); 
    error RequestAlreadyExists(address account); 
    error PotentialAccountOnly(address account);
    error RequestDoesntExists(address account);

    mapping(address => bool) public isSubscribed; // Are they subscribed?
    mapping(address => Membership) public memberships; // Represents Memberships
    
    mapping(address subacct => PendingRequest) public pendingRequests; // Represents Pending Approvals
    mapping(address _to => bool) public sentApproval; // Has the approval been sent?

    //mapping(address subaccount => address mainholder) //Are they a sub account? 

    /// @notice This modifier checks to see if the subscription is active by: 
    /// @notice 1. Makes sure the owner of the contract cannot perform certain functions
    /// @notice 2. Makes sure only the main account holder can perform that certain function
    /// @notice 3. Makes sure that person is subscribed
    modifier isActive() {
        _ownerNotAllowed();
        _mainAcctOnly();
        _membershipDoesntExists();
        _membershipExpired();                 
        _; 
    }

    /// @notice This modifier checks to see if the pending approval has been approved by: 
    /// @notice 1. Makes sure the owner of the contract cannot perform this action 
    /// @notice 2. Makes sure the approval type is correct (Non-Fractional or Fractional) 
    /// @notice 3. Makes sure the approval has been approved
    /// @param account represents the approval


    /// @notice This modifier checks to see if the potential account, which is a possible 
    /// @notice sub account user, already has their own subscription where they are the main holder
    /// @param account represents who the request is going to
    modifier VerifyRequest(address account) {
        _membershipAlreadyExists(account);
        _doesRequestExists(account);
        _; 
    }

    modifier isAvailableToRenew() {
        _ownerNotAllowed();
        _mainAcctOnly();
        _membershipDoesntExists();
        _;
    }

    modifier _isPotentialAccount() {
        _onlyPotentialSubAcct(msg.sender);
        _;
    }

    function _ownerNotAllowed() internal view virtual {
        if (msg.sender == owner()) {
            revert OwnerNotAllowed(owner());
        }
    }

    function _onlyPotentialSubAcct(address account) internal view virtual {
        if (pendingRequests[account].to != msg.sender) {
            revert PotentialAccountOnly(account); 
        }
    }

    function _membershipDoesntExists() internal view virtual {
        if (isSubscribed[msg.sender] != true) {
            revert MembershipDoesntExists(msg.sender); 
        }
    }

    function _membershipExpired() internal virtual {
        if (block.timestamp > subscriptionData.timeframe) {  
            revert MembershipExpired(msg.sender); 
        }

    }

    function _mainAcctOnly() internal view virtual {
        if (msg.sender != memberships[msg.sender].mainAcct) {
            revert MainAcctOnly(); 
        }
    } 

    function _membershipAlreadyExists(address account) internal view virtual {
        if (account == address(0)) {
            if (isSubscribed[msg.sender] == true) {
                revert MembershipAlreadyExists(msg.sender);
            }
        }

        if (isSubscribed[account] == true) {
            revert MembershipAlreadyExists(account);
        }
    }

    function _notApproved(address account) internal view virtual {
        PendingRequest storage getApproval = pendingRequests[account];

        if (getApproval.status != true) {
            revert NotApproved();
        }
    }

    function _doesRequestExists(address account) internal view virtual {
        if(sentApproval[account] == true) {
            revert RequestAlreadyExists(account);
        }
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
        _ownerNotAllowed();
        _membershipAlreadyExists(address(0));

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
    function cancel() external isActive  {   
        isSubscribed[msg.sender] = false;
        memberships[msg.sender].ownedPreviousMembership = true; 
        subscriptionData.cancellations++;
        subscriptionData.subscribers--; 

        emit CancelSubscription(msg.sender);
    }

    /// @custom:removefunction I may remove this function 
    /// REMINDER: Test Functionality
    function deleteMembership() external isActive  {
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

    function sendJoinRequest(address _to, RequestType _requestType) external isActive VerifyRequest(_to) {
        PendingRequest memory _pendingRequest = PendingRequest({
            from: msg.sender, to: _to, status: false, requestType: _requestType 
            });

        pendingRequests[_to] = _pendingRequest;
        
        emit SendInvite(msg.sender, _to, _requestType);
    }

    /// @notice Allow users to confirm they have approved a split account or sub account subscription
    function confirmRequest() external virtual _isPotentialAccount {
        PendingRequest storage _pendingRequest = pendingRequests[msg.sender];
        _pendingRequest.status = true;

        emit ConfirmRequest(_pendingRequest.from);
        
    }
    
    /// @notice Allows potential sub account holders to reject an approval 
    /// @param _from represents who the pending request is coming from (sender)
    function rejectRequest(address _from) external virtual _isPotentialAccount {
        _ownerNotAllowed();
        if(_from == pendingRequests[msg.sender].from) {
            delete pendingRequests[msg.sender];
            emit RejectRequest(msg.sender); 
        }

        else {
            revert RequestDoesntExists(_from);
        }
        
    }

    function addPotentialAccount(address _account) external isActive {
        _notApproved(_account);
        Membership storage _membership = memberships[msg.sender]; 
        PendingRequest storage getRequestType = pendingRequests[_account];
        SubAccount memory createSubAcct = SubAccount({
            parentAccount: msg.sender, 
            subAccount: _account, 
            subAccountType: getRequestType.requestType
        }); 

        _membership.children[_account] = createSubAcct;

        emit AddedToMembership(msg.sender, _account);
    }

    // renew a persons membership
    // checks to see if they have a membership
    // makes them pay the subscription fee to renew membership
    function renew() external view isAvailableToRenew {
        //if (block.timestamp > subscription.timeframe)      
        // require() some sort of payment from the msg.sender
        // membership.expired = false 
    }
}