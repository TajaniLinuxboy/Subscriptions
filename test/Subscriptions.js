const { expect } = require("chai"); 
const hre = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers"); 

describe("Subscription Contract", () => {
    const name = "KeySubscription"; 
    const price = 100; 
    const timeframe = 600;



    let subscription;

    async function getWallets() {
        const [owner, mainAcct, subAcct] = await hre.ethers.getSigners();
        return {owner, mainAcct, subAcct};
    }

    before(async() => {
        subscription = await hre.ethers.getContractFactory("Subscription");
        subscription = await subscription.deploy(name, price, timeframe);
    }); 


    it("Test subscribe(): Subscribes to subscription successfully", async () => {
        const getSubscribers = Number(await subscription.getSubscribers());
        const getCancellations = Number(await subscription.getCancellations());       
        const getSubscriptionData = await subscription.subscriptionData() ; 

        const subscriptionPrice = Number(getSubscriptionData.price); 
        const subscriptionName = String(getSubscriptionData.name); 

        expect(getSubscribers).to.equal(0); 
        expect(getCancellations).to.equal(0);         
        expect(subscriptionName).to.equal(name);
        expect(subscriptionPrice).to.equal(price); 
    });

    it("Test: subscribe(), Subscribe to subscription & Verify new subscriber", async () => {
        const {mainAcct} = await loadFixture(getWallets)
        await subscription.connect(mainAcct).subscribe(); 
        
        const acctHolder = await subscription.memberships(mainAcct);        
        const isSubscribed = await subscription.isSubscribed(mainAcct);
        const getSubscribers = Number(await subscription.getSubscribers()); 

        expect(getSubscribers).to.equal(1);
        expect(isSubscribed).to.equal(true);
        expect(acctHolder.mainAcct, mainAcct);
    }); 

    it("Test: subscribe(), Revert(MembershipAlreadyExists), If account is already subscribed", async () => {
        const {mainAcct} = await loadFixture(getWallets);
        await subscription.connect(mainAcct).subscribe();
        //subscribe again
        await expect(subscription.connect(mainAcct).subscribe()).to.be.revertedWithCustomError(
            subscription, 
            "MembershipAlreadyExists"
        ).withArgs(mainAcct);
    }); 

    it("Test: cancel(), Cancel membership", async() => {
        const {mainAcct} = await loadFixture(getWallets);
        await subscription.connect(mainAcct).subscribe(); 
        await subscription.connect(mainAcct).cancel();

        const isSubscribed = await subscription.isSubscribed(mainAcct);      
        const membership = await subscription.memberships(mainAcct);

        expect(membership.ownedPreviousMembership).to.equal(true);
        expect(isSubscribed).to.equal(false);
    }); 

    it("Test: changePrice(), Only allow owner of contract to change price of subscription", async () => {
        await subscription.changePrice(200); 
        const getSubscriptionData = await subscription.subscriptionData(); 
        const price = Number(await getSubscriptionData.price); 

        expect(price).to.equal(200);
    }); 

    it("Test: changePrice(), Revert(onlyOwner), Only the owner can set a new price", async () => {
        const {mainAcct} = await loadFixture(getWallets);
        await expect(subscription.connect(mainAcct).changePrice(200)).to.be.revertedWithCustomError(
            subscription, 
            "OwnableUnauthorizedAccount"
        ).withArgs(mainAcct);
    }); 

    /* START: Nonfractional Request */
    
    it("Test: sendJoinRequest(), Send nonfractionlized request to specified user", async () => {
        const {mainAcct, subAcct} = await loadFixture(getWallets);
        const nonfractionalrequest = 0 

        await subscription.connect(mainAcct).subscribe();
        await subscription.connect(mainAcct).sendJoinRequest(subAcct);         
        const isSent = await subscription.sentApproval(subAcct); 

        expect(isSent).to.equal(true);
    });

    it("Test: sendJoinRequest(), Revert(MembershipAlreadyExists), Potential subacct already has an account", async () => {
        const {mainAcct, subAcct} = await loadFixture(getWallets);
        const nonfractionalrequest = 0

        await subscription.connect(mainAcct).subscribe(); 
        await expect(subscription.connect(mainAcct).sendJoinRequest(mainAcct, nonfractionalrequest)).to.be.revertedWithCustomError(
            subscription, 
            "MembershipAlreadyExists"           
        ).withArgs(mainAcct); 
        
    }); 

    it("Test: sendJoinRequest(), Revert(RequestAlreadyExists), Request to account was already sent", async () => {
        const {mainAcct, subAcct} = await loadFixture(getWallets);
        const nonfractionalrequest = 0
        await subscription.connect(mainAcct).subscribe();
        await subscription.connect(mainAcct).sendJoinRequest(subAcct, nonfractionalrequest);         
        //send another request to the same user 

        await expect(subscription.connect(mainAcct).sendJoinRequest(subAcct, nonfractionalrequest)).to.be.revertedWithCustomError(
            subscription, 
            "RequestAlreadyExists"
        ).withArgs(subAcct);
    });

    it("Test: sendJoinRequest(), Revert(OwnerNotAllowed), Owner of contract is not allowed to send request", async () => {
        const {owner, mainAcct} = await loadFixture(getWallets);
        const nonfractionalrequest = 0

        await expect(subscription.sendJoinRequest(mainAcct, nonfractionalrequest)).to.be.revertedWithCustomError(
            subscription, 
            "OwnerNotAllowed"
        ).withArgs(owner);
    });

    /* END: Nonfractional Request*/


    /* START: Fractional Request */

    it("Test: sendJoinRequest(), Send fractionalized request to specified user", async () => {
        const {mainAcct, subAcct} = await loadFixture(getWallets);
        const fractionalrequest = 1

        await subscription.connect(mainAcct).subscribe();
        await subscription.connect(mainAcct).sendJoinRequest(subAcct, fractionalrequest);         
        const isSent = await subscription.sentApproval(subAcct); 

        expect(isSent).to.equal(true);
    });
    
    /* END: Fractional Request */


    it("Test: confirmRequest(), Confirm approval through potential subaccount", async () => {
        const {mainAcct, subAcct} = await loadFixture(getWallets);
        const nonfractionalrequest = 0;
        const useMainAcct = await subscription.connect(mainAcct);
        await useMainAcct.subscribe(); 
        await useMainAcct.sendJoinRequest(subAcct, nonfractionalrequest);

        await subscription.connect(subAcct).confirmRequest(nonfractionalrequest);
        const pendingapproval = await subscription.pendingRequests(subAcct);
    
        expect(pendingapproval.status).to.equal(true);
    });

    it("Test: confirmRequest(), Revert(PotentialAccountOnly), Only potential account can confirm approval", async () => {
        const {mainAcct, subAcct} = await loadFixture(getWallets);
        const useMainAcct = await subscription.connect(mainAcct);
        const nonfractionalrequest = 0;

        await useMainAcct.subscribe();
        await useMainAcct.sendJoinRequest(subAcct, nonfractionalrequest);

        await expect(subscription.connect(mainAcct).confirmRequest()).to.be.revertedWithCustomError(
            subscription, 
            "PotentialAccountOnly"
        ).withArgs(mainAcct);

    });

    it("Test: rejectRequest(), Remove the pending approval", async() => {
        const {mainAcct, subAcct} = await loadFixture(getWallets);
        const useMainAcct = await subscription.connect(mainAcct);
        const nonfractionalrequest = 0;

        await useMainAcct.subscribe();
        await useMainAcct.sendJoinRequest(subAcct, nonfractionalrequest);
        await subscription.connect(subAcct).rejectRequest(mainAcct);

        const pendingapproval = await subscription.pendingRequests(subAcct);

        expect(pendingapproval.status).to.equal(false);
    });

    it("Test: rejectRequest(), Revert(RequestDoesntExists), Should revert if the pending request is not found", async () => {
        const {owner, mainAcct, subAcct} = await loadFixture(getWallets);
        const useMainAcct = await subscription.connect(mainAcct);

        await useMainAcct.subscribe();
        await useMainAcct.sendJoinRequest(subAcct);
        await expect(subscription.connect(subAcct).rejectRequest(owner)).to.be.revertedWithCustomError(
            subscription, 
            "RequestDoesntExists"
        ).withArgs(owner);
    })

})