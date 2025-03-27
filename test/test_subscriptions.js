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

    //const rootInstance = Subscription.new(_name, _price, _timeframe);

    it("Test to see if a subscription was created sucessfully", async () => {

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
    
    
    it("Test subscribe()", async () => {
        await rootInstance.subscribe({from: mainHolderAcct}); 
        const getSubscribers = await rootInstance.getSubscribers.call(); 

        assert.equal(getSubscribers, 1); 
    }); 

    it("Test if they're subscribed to the subscription", async() => {
        const isSubscribed = await rootInstance._subscribed(mainHolderAcct); 
        assert.equal(isSubscribed, true);
    });

})