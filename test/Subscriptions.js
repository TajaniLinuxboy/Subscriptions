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

    /* START: sendNonFractionalizedRequest */
    
    it("Test: sendNonFractioalizedRequest(), Send nonfractionlized request to specified user", async () => {
        const {mainAcct, subAcct} = await loadFixture(getWallets);
        await subscription.connect(mainAcct).subscribe();
        await subscription.connect(mainAcct).sendNonFractionalizedRequest(subAcct);         
        const isSent = await subscription.sentApproval(subAcct); 

        expect(isSent).to.equal(true);
    });

    it("Test: sendNonFractionalizedRequest(), Revert(MembershipAlreadyExists), Potential subacct already has an account", async () => {
        const {mainAcct, subAcct} = await loadFixture(getWallets); 
        await subscription.connect(mainAcct).subscribe(); 
        await expect(subscription.connect(mainAcct).sendNonFractionalizedRequest(mainAcct)).to.be.revertedWithCustomError(
            subscription, 
            "MembershipAlreadyExists"           
        ).withArgs(mainAcct); 
        
    }); 

    it("Test: sendNonFractionalizedRequest(), Revert(RequestAlreadyExists), Request to account was already sent", async () => {
        const {mainAcct, subAcct} = await loadFixture(getWallets);
        await subscription.connect(mainAcct).subscribe();
        await subscription.connect(mainAcct).sendNonFractionalizedRequest(subAcct);         
        //send another request to the same user 

        await expect(subscription.connect(mainAcct).sendNonFractionalizedRequest(subAcct)).to.be.revertedWithCustomError(
            subscription, 
            "RequestAlreadyExists"
        ).withArgs(subAcct);
    });

    it("Test: sendNonFractionalizedRequest(), Revert(OwnerNotAllowed), Owner of contract is not allowed to send request", async () => {
        const {owner, mainAcct} = await loadFixture(getWallets);
        await expect(subscription.sendNonFractionalizedRequest(mainAcct)).to.be.revertedWithCustomError(
            subscription, 
            "OwnerNotAllowed"
        ).withArgs(owner);
    });

    /* END: sendNonFractionalizedRequest */

    /* START: sendFractionalizedRequest */
    it("Test: sendNonFractionalizedInvitation(), Send nonfractionlized request to specified user", async () => {
        const {mainAcct, subAcct} = await loadFixture(getWallets);
        await subscription.connect(mainAcct).subscribe();
        await subscription.connect(mainAcct).sendFractionalizedRequest(subAcct);         
        const isSent = await subscription.sentApproval(subAcct); 

        expect(isSent).to.equal(true);
    });

    it("Test: sendFractionalizedRequest(), Revert(MembershipAlreadyExists), Potential subacct already has an account", async () => {
        const {mainAcct, subAcct} = await loadFixture(getWallets); 
        await subscription.connect(mainAcct).subscribe(); 
        await expect(subscription.connect(mainAcct).sendFractionalizedRequest(mainAcct)).to.be.revertedWithCustomError(
            subscription, 
            "MembershipAlreadyExists"           
        ).withArgs(mainAcct); 
        
    }); 

    it("Test: sendFractionalizedRequest(), Revert(RequestAlreadyExists), Request to account was already sent", async () => {
        const {mainAcct, subAcct} = await loadFixture(getWallets);
        await subscription.connect(mainAcct).subscribe();
        await subscription.connect(mainAcct).sendFractionalizedRequest(subAcct);         
        //send another request to the same user 

        await expect(subscription.connect(mainAcct).sendFractionalizedRequest(subAcct)).to.be.revertedWithCustomError(
            subscription, 
            "RequestAlreadyExists"
        ).withArgs(subAcct);
    });

    it("Test: sendFractionalizedRequest(), Revert(OwnerNotAllowed), Owner of contract is not allowed to send request", async () => {
        const {owner, mainAcct} = await loadFixture(getWallets);
        await expect(subscription.sendFractionalizedRequest(mainAcct)).to.be.revertedWithCustomError(
            subscription, 
            "OwnerNotAllowed"
        ).withArgs(owner);
    });

    /* END: sendFractionalizedRequest */
})