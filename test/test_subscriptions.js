const Subscription = artifacts.require("Subscription"); 

contract("Subscriptions", (accounts) => {
    const _name = "KeySubscription"; 
    const _price = 100; 
    const _timeframe = 0;

    
    let rootInstance; 
    let ownerOfContract = accounts[0];
    let mainHolderAcct = accounts[1];
   

    before(async() => {
        rootInstance = await Subscription.new(_name, _price, _timeframe);
    })

    it("Test: If subscription was created sucessfully", async () => {

        const amtOfSubs = await rootInstance.getSubscribers.call();
        const amtOfCancellations = await rootInstance.getCancellations.call(); 
        const getSubscriptionStruct = await rootInstance.getSubscriptionInfo.call(); 
        const name = getSubscriptionStruct.name; 
        const price = getSubscriptionStruct.price; 

        assert.equal(amtOfSubs, 0); 
        assert.equal(amtOfCancellations, 0); 
        assert.equal(_name, name); 
        assert.equal(_price, price);
    });

    
    it("Test: If the user was able to subscribe", async () => {
        await rootInstance.subscribe({from: mainHolderAcct}); 
        const getSubscribers = await rootInstance.getSubscribers.call(); 

        assert.equal(getSubscribers, 1); 
    }); 

    it("Test: If they're subscribed to the subscription", async() => {
        const isSubscribed = await rootInstance._subscribed(mainHolderAcct); 
        assert.equal(isSubscribed, true);
    });

    it("Test: If newly subscribed account became the main account holder", async() => {
        const acctHolder = await rootInstance.subscription(mainHolderAcct);
        assert.equal(acctHolder.mainAcct, mainHolderAcct);
    }); 

    it("Test: Should not allow user with an account to subscribe again", async() => {
        const errMsg = "You already have a subscription"; 
        const revertString = `VM Exception while processing transaction: revert ${errMsg} -- Reason given: ${errMsg}.`; 

        try {
            await rootInstance.subscribe({from: mainHolderAcct}); 
            assert.fail(""); 
        }

        catch(error) {
            assert.equal(error.message, revertString);
        }
    });

    it("Test: Should not allow owner of contract to subscribe to their own subscription", async() => {
        const errMsg = "You cannot perform this action"; 
        const revertString = `VM Exception while processing transaction: revert ${errMsg} -- Reason given: ${errMsg}.`; 

        try {
            await rootInstance.subscribe({from: ownerOfContract}); 
            assert.fail(""); 
        }

        catch(error) {
            assert.equal(error.message, revertString);
        }
    });

    it("Test: Membership price should be eq to the subscription price", async() => {
        const getMembershipPrice = await rootInstance.subscription(mainHolderAcct); 
        const getSubscriptionPrice = await rootInstance.getSubscriptionInfo(); 
        assert.equal(getSubscriptionPrice.price, getMembershipPrice.price); 
    }); 

    it("Test: Should cancel main holder's membership", async() => {
        await rootInstance.cancel({from: mainHolderAcct}); 
        const isSubscribed = await rootInstance._subscribed(mainHolderAcct); 
        assert.equal(isSubscribed, false); 
    }); 

    it("Test: Set ownedPreviousMembership flag to true after canceling", async() => {
        const membership = await rootInstance.subscription(mainHolderAcct);
        assert.equal(membership.ownedPreviousMembership, true); 
    });
})