/// @author Keshawn
/// @title Subscription Project
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0; 

import "@openzeppelin/contracts/access/Ownable.sol";

contract Subscription is Ownable { 

    string internal name; 
    uint internal price; 
    uint internal timeFrame; 
    uint private _subscribers; 
    uint private _cancellations; 

    struct SubscriptionData {
        uint price; 
        uint timeframe; 
        uint subscribers; 
        uint cancellations;
        string name;
    }

    SubscriptionData public subscriptionData;

    /// @notice Constructor Initiates Subscription Data Struct
    /// @param _name Represents the name ef the subscription
    /// @param _price Represents the price of the subscription in usd
    /// @param _timeframe Represents the timeframe for the subscription (i.e 1 month, 2 month) in seconds
    /// @dev other paramters included default values set by the variables in the beginning 
    constructor(string memory _name, uint _price, uint _timeframe) Ownable(msg.sender) {
        require(_timeframe % 60 == 0, "Time frame has to be evenly divisble by 60");

       subscriptionData = SubscriptionData(
        _price, 
        _timeframe, 
        _subscribers,
         _cancellations, 
         _name
        ); 
    }

    struct Membership {
        uint price; 
        address mainAcct; 
        uint timeLimit; 
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

    /// @custom:events Custom Events
    event StatusChanged(address indexed account, bool _newStatus, bool _oldStatus);
    event Subscribed(address indexed account, uint price); 
    event CancelSubscription(address indexed account); 
    event DeleteMembership(address indexed account);
    event PriceUpdate(string indexed name, uint price);
    event SendInvite(address indexed from, address to, RequestType _requestType); 
    event ConfirmRequest(address indexed from);
    event RejectRequest(address indexed account); 
    event AddedToMembership(address indexed parentAccount, address account);
    event RenewedMembership(address indexed account);

    ///@custom:errors Custom Errors
    error OwnerNotAllowed(address owner); 
    error MainAcctOnly();
    error IncorrectApprovalType(RequestType _requestType); 
    error NotApproved(); 
    error MembershipDoesntExists(address account);      
    error MembershipExpired(address account);
    error MembershipAlreadyExists(address account); 
    //error MembershipIsNotActive(address account);
    error RequestAlreadyExists(address account); 
    error PotentialAccountOnly(address account);
    error RequestDoesntExists(address account);

    mapping(address => bool) public isSubscribed; // Are they subscribed?
    mapping(address => Membership) public memberships; // Represents Memberships
    
    mapping(address subacct => PendingRequest) public pendingRequests; // Represents Pending Approvals
    mapping(address _to => bool) public sentApproval; // Has the approval been sent?
    mapping(address => SubAccount) children; // Are they a sub account?

    /// @notice This modifier checks to see if the subscription is active by: 
    /// @notice 1. Makes sure the owner of the contract cannot perform certain functions
    /// @notice 2. Makes sure only the main account holder can perform that certain function
    /// @notice 3. Makes sure that person is subscribed
    /// @notice 4. Makes sure the membership isn't expired
    modifier isActive() {
        _ownerNotAllowed();
        _mainAcctOnly();
        _membershipDoesntExists();
        _membershipExpired();                 
        _; 
    }


    /// @notice This modifier checks to see if the request is valid
    /// @notice 1. If membership exists already, then revert
    /// @notice 2. If the request for this account exists already, then revert
    /// @param account Represents what account needs to be verified
    modifier VerifyRequest(address account) {
        _membershipAlreadyExists(account);
        _doesRequestExists(account);
        _; 
    }

    /// @notice This modifier is similar to isActive(), but checks to if the membership
    /// @notice is available to be renewed
    /// @notice 1. Owner cannot perform this action; 
    /// @notice 2. Only main account holder can perform this action
    /// @notice 3. Checks to see if membership exists
    modifier verifyAcctForRenewal() {
        _ownerNotAllowed();
        _mainAcctOnly();
        _membershipDoesntExists();
        _;
    }

    /// @notice This modifier only allows a subaccount holder to perform action
    modifier onlySubAcct() {
        _onlyPotentialSubAcct(msg.sender);
        _;
    }

    /// @notice Owner cannot perform action
    function _ownerNotAllowed() internal view virtual {
        if (msg.sender == owner()) {
            revert OwnerNotAllowed(owner());
        }
    }

    /// @notice Only sub account holder can perfom action
    function _onlyPotentialSubAcct(address account) internal view virtual {
        if (pendingRequests[account].to != msg.sender) {
            revert PotentialAccountOnly(account); 
        }
    }

    /// @notice Revert if membership doesn't exists
    function _membershipDoesntExists() internal view virtual {
        if (isSubscribed[msg.sender] != true) {
            revert MembershipDoesntExists(msg.sender); 
        }
    }

    /// @notice Revert if membership has expired
    function _membershipExpired() internal virtual {
        Membership storage member = memberships[msg.sender];
        if (block.timestamp > member.timeLimit) {  
            revert MembershipExpired(msg.sender); 
        }

    }

    /// @notice Only main account can perform action
    function _mainAcctOnly() internal view virtual {
        if (msg.sender != memberships[msg.sender].mainAcct) {
            revert MainAcctOnly(); 
        }
    } 

    /// @notice Revert if membership exists already
    function _membershipAlreadyExists(address account) internal view virtual {
        if (account == address(0)) { //If no account value is passed, will use msg.sender instead
            if (isSubscribed[msg.sender] == true) {
                revert MembershipAlreadyExists(msg.sender);
            }
        }

        if (isSubscribed[account] == true) {
            revert MembershipAlreadyExists(account);
        }
    }

    /// @notice Revert if pending request hasn't been approved
    function _notApproved(address account) internal view virtual {
        PendingRequest storage getApproval = pendingRequests[account];

        if (getApproval.status != true) {
            revert NotApproved();
        }
    }

    /// @notice Revert if request to account already exists
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
    function subscribe() public payable virtual {
        _ownerNotAllowed();
        _membershipAlreadyExists(address(0));

        if (memberships[msg.sender].ownedPreviousMembership == false){
            Membership memory _member; 
            _member.mainAcct = msg.sender;
            _member.timeLimit = block.timestamp + subscriptionData.timeframe;  

            memberships[msg.sender] = _member;  
            isSubscribed[msg.sender] = true;
            subscriptionData.subscribers++;

            emit Subscribed(msg.sender, subscriptionData.price);
        }

        else {
            Membership memory _member; 
            _member.mainAcct = msg.sender;  
            _member.timeLimit = block.timestamp + subscriptionData.timeframe;  

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


    /// @notice Sends a pending request to specified account
    /// @param _to Represents who the request is being sent to
    /// @param _requestType Represents the request type (Fractional/NonFractional)
    function sendJoinRequest(address _to, RequestType _requestType) external isActive VerifyRequest(_to) {
        PendingRequest memory _pendingRequest = PendingRequest({
            from: msg.sender, to: _to, status: false, requestType: _requestType 
            });

        pendingRequests[_to] = _pendingRequest;
        
        emit SendInvite(msg.sender, _to, _requestType);
    }

    /// @notice Allow potential subaccount holder to approve/confirm request
    function confirmRequest() external virtual onlySubAcct {
        PendingRequest storage _pendingRequest = pendingRequests[msg.sender];
        _pendingRequest.status = true;

        emit ConfirmRequest(_pendingRequest.from);
        
    }
    
    /// @notice Allows potential sub account holders to reject an approval 
    /// @notice Reverts if request doesn't exists
    /// @param _from represents who the pending request is coming from (sender)
    function rejectRequest(address _from) external virtual onlySubAcct {
        _ownerNotAllowed();
        if(_from == pendingRequests[msg.sender].from) {
            delete pendingRequests[msg.sender];
            emit RejectRequest(msg.sender); 
        }

        else {
            revert RequestDoesntExists(_from);
        }
        
    }

    /// @notice Adds potential account (subaccount) to parent membership
    /// @param _account Represents who is being added to the membership
    function addPotentialAccount(address _account) external isActive {
        _notApproved(_account);
        PendingRequest storage getRequestType = pendingRequests[_account];
        SubAccount memory createSubAcct = SubAccount({
            parentAccount: msg.sender, 
            subAccount: _account, 
            subAccountType: getRequestType.requestType
        }); 

        children[_account] = createSubAcct;

        emit AddedToMembership(msg.sender, _account);
    }

    function renew() public virtual payable verifyAcctForRenewal {
        Membership storage member = memberships[msg.sender];
        member.timeLimit = block.timestamp + subscriptionData.timeframe;

        emit RenewedMembership(msg.sender); 
    }
}