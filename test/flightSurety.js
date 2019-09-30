
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');
var Web3 = require('web3');
let web33 = new Web3(new Web3.providers.HttpProvider("http://127.0.0.1:8545"));


const AIRLINE_FUNDED_AMOUNT = web3.toWei('10', 'ether');


const FLIGHT_CODE = 'ND1309';
const TIMESTAMP = Math.floor(Date.now() / 1000);


contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  
  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {

        await config.flightSuretyApp.registerAirline.call(newAirline, {from: config.firstAirline});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.isAirlineRegistered.call(newAirline); 

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });

  it('(airline) If airline is funded can register a new airline', async () => {

    // ARRANGE
    let newAirline = accounts[2];
    let result = false;
    // ACT
    try {

        let result1 = await config.flightSuretyData.getAirlineStatus.call(config.firstAirline);

        //console.log(`Registered: ${result1[0]}, aproved: ${result1[1]}, active: ${result1[2]}`);

        await config.flightSuretyApp.fundAirline({value: AIRLINE_FUNDED_AMOUNT, from: config.firstAirline});

        let result2 = await config.flightSuretyData.getAirlineStatus.call(config.firstAirline);

        //console.log(`After funding -> Registered: ${result2[0]}, aproved: ${result2[1]}, active: ${result2[2]}`);

        
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});

        result = await config.flightSuretyData.isAirlineRegistered.call(newAirline);
    }
    catch(e) {

        //console.log(`ERROR (register new airline): ${e}`);

    }

    // ASSERT
    assert.equal(result, true, "Airline should be able to register another one after providing funding");

  });

  

  it('(multyparty) only the first registered airline can register and aprove new airlines until at least 4 airlines are registered', async () => {

    // ARRANGE
    let fifthAirline = accounts[5];
    let result = true;
    // ACT
    try {

        for(let a=3; a<6; a++) {      
            let numAirlines = await config.flightSuretyData.getNumRegAirlines.call();
            //console.log(`Registered airines: ${numAirlines}`);
            let newAirline = accounts[a];
            await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    
            let result1 = await config.flightSuretyData.getAirlineStatus.call(newAirline);

            //console.log(`Airline ${a} -> Registered: ${result1[0]}, aproved: ${result1[1]}, active: ${result1[2]}`);
        }


        result = await config.flightSuretyData.isAirlineAproved.call(fifthAirline);

    }
    catch(e) {
        //onsole.log(`ERROR: ${e}`);
    }
    
    // ASSERT
    
    assert.equal(result, false, "Airline should not be able to register and aprove a fifth airline");

  });

  it('(multyparty) registration of fifth and subsequent airlines requires 50% consensus of active airlines', async () => {

    // ARRANGE
    let result = false;
    let newAirline = accounts[6];
    // ACT

    try {


        for (let j=2; j<5; j++) {
            let registeredAirline = accounts[j];
            await config.flightSuretyApp.fundAirline({value: AIRLINE_FUNDED_AMOUNT, from: registeredAirline});

            // Fund the airline
            let result1 = await config.flightSuretyData.getAirlineStatus.call(registeredAirline);
            //console.log(`Airline ${j} -> Registered: ${result1[0]}, aproved: ${result1[1]}, active: ${result1[2]}`);

        }

        // Register new airline

        await config.flightSuretyApp.registerAirline(newAirline, {from: accounts[3]});

        let res = await config.flightSuretyData.getAirlineStatus.call(newAirline);

        //console.log(`Airline ${newAirline} -> Registered: ${res[0]}, aproved: ${res[1]}, active: ${res[2]}`);

        votes = [true, false, true, true];

        for (let h=1; h<5; h++) {
            // Vote
            let registeredAirline = accounts[h]
            //console.log(`AIRLINE to VOTE: ${registeredAirline}`);
            await config.flightSuretyApp.aproveAirline(newAirline, votes[h-1], {from: registeredAirline});

            let result2 = await config.flightSuretyData.getVotesInfo.call(newAirline);
            
            //console.log(`Vote ${h} for ${newAirline} -> Required: ${result2[0]}, Aproved: ${result2[1]}`);
        }

        result = await config.flightSuretyData.isAirlineAproved.call(newAirline);
    }
    catch(e) {
        //console.log(`ERROR: ${e}`);
    }

    // ASSET
    assert.equal(result, true, "Airline is aproved after multiparty consensus votes");

  });

  

  it('(flight) a funded airline can register a flight', async () => {
      // ARRANGE
      //const flightCode = 'ND1309';
      //let timestamp = Math.floor(Date.now() / 1000);
      let airlineAddress = accounts[1];
    
      const flightCode = FLIGHT_CODE;
      let timestamp = TIMESTAMP;
    
      // ACT
      let flightKey = await config.flightSuretyData.getFlightKey(airlineAddress, flightCode, timestamp);
      //console.log(`Flight key: ${flightKey}`);
      let before = await config.flightSuretyData.isFlightRegistered.call(flightKey);
      await config.flightSuretyApp.registerFlight(flightCode, timestamp, {from: airlineAddress});
      let after = await config.flightSuretyData.isFlightRegistered.call(flightKey);

      // ASSERT
      assert.equal(before, false, "Flight is already registered");
      assert.equal(after, true, "Fligh not registered");

  });

  it('(passangers) can not pay more than 1eth to purchase flight insurance', async () => {

    //ARRANGE
    let passanger = accounts[10];
    const amount = web3.toWei('2', 'ether');
    let airlineAddress = accounts[1];
    const flightCode = FLIGHT_CODE;
    let timestamp = TIMESTAMP;

    //ACT
    let isPurchased = true;
    try
    {
        let flightKey = await config.flightSuretyData.getFlightKey(airlineAddress, flightCode, timestamp);
        //console.log(`FLIGHT KEY: ${flightKey}`);
        await config.flightSuretyApp.purchaseInsurance(flightKey, {value: amount, from: passanger});
    }
    catch(e)
    {
        //console.log(e);
        isPurchased = false;

    }
    
    //ASSERT
    assert.equal(isPurchased, false, "Not possible to purchase");
  });

  it('(passangers) may pay up to 1 ether for purchasing flight insurance', async () => {

    // ARRANGE
    let passenger = accounts[11];
    
    const amount = web3.toWei('1', 'ether');
    let airlineAddress = accounts[1];
    const flightCode = FLIGHT_CODE;
    let timestamp = TIMESTAMP;

    let isRegistered = false;
    let insuranceAmount = 0;
    // ACT
    try
    {
 
        let flightKey = await config.flightSuretyData.getFlightKey(airlineAddress, flightCode, timestamp);
        //console.log(`FLIGHT KEY: ${flightKey}`);
        await config.flightSuretyApp.purchaseInsurance(flightKey, {value: amount, from: passenger});

        isRegistered = await config.flightSuretyData.isPassengerRegistered.call(passenger);
        //console.log(`Is registered: ${isRegistered}`);
        let insurance = await config.flightSuretyData.getInsuranceInfo.call(passenger, flightCode);
        insuranceAmount = insurance[1];

        //console.log(`Airline: ${insurance[0]}, Amount: ${insurance[1]}, AmountToPay: ${insurance[2]}, Registered: ${insurance[3]}, Refunded: ${insurance[4]}`);
    
    }
    catch(e)
    {
        //console.log(e);

    }
    
    // ASSSERT
    assert.equal(isRegistered, true, "Passanger is not registered");
    assert.equal(insuranceAmount, amount, "Insurance amount is not the same that the amount paid");


  });

  it('(passengers) flight delayed due to airline fault, passenger receives credit of 1.5X the amount they paid', async () => {

    // ARRANGE
    let airlineAddress = accounts[1];
    let passenger = accounts[11];
    const FLIGHT_DELAY_STATUS_CODE = 20
    const flightCode = FLIGHT_CODE;
    let timestamp = TIMESTAMP;


    let resultCode = 0;
    let amountToPay = 0;
    // ACT
    try 
    {

        await config.flightSuretyApp.processFlightStatus(airlineAddress, flightCode, timestamp, FLIGHT_DELAY_STATUS_CODE)
        resultCode = await config.flightSuretyData.getFlightStatus.call(airlineAddress, flightCode, timestamp);

        let insurance = await config.flightSuretyData.getInsuranceInfo.call(passenger, flightCode);
        amountToPay = insurance[2];
        
    }
    catch(e)
    {
        //console.log(e);
    }
    
    // ASSERT
    assert.equal(resultCode, 20, "Status code has not been updated");
    assert.equal(web3.fromWei(amountToPay, 'ether'), 1.5, "Amount to pay to the user is not correct");

  });

  it('(passengers) passanger can request the payout due to delayed flight', async () => {
    // ARRANGE
    let passenger = accounts[11];
    const flightCode = FLIGHT_CODE;

    let isRefunded = false;
    let passengerBalance = 0;
    // ACT
    try
    {

        await config.flightSuretyApp.insurancePayout(passenger);
        let result = await config.flightSuretyData.getInsuranceInfo.call(passenger, flightCode);
        isRefunded = result[4];
        passengerBalance = await config.flightSuretyData.getPassengerBalance.call(passenger);
    }
    catch(e)
    {
        //console.log(`ERROR: ${e}`);
    }
    // ASSERT
    assert.equal(isRefunded, true, "Insurance has not been refunded");
    assert.equal(web3.fromWei(passengerBalance, 'ether'), 1.5, "Passanger balance is not correct");

 
  });

  it('(passengers) insuree funds are withdrawn to insuree wallet', async () => {

    // ARRANGE
    let passenger = accounts[11];
    const currentBalanceIni = await web33.eth.getBalance(passenger);
    const amount = web3.toWei('1', 'ether');

    let passengerBalanceIni = await config.flightSuretyData.getPassengerBalance.call(passenger);

    let passengerBalance = -1;
    let currentBalanceEnd = -1
    // ACT
    try
    {
        await config.flightSuretyApp.withdrawBalance(passenger, amount);
        passengerBalance = await config.flightSuretyData.getPassengerBalance.call(passenger);
        currentBalanceEnd = await web33.eth.getBalance(passenger);
    }
    catch(e)
    {
        // console.log(e);
    }
    // ASSERT
    assert.equal(passengerBalance, passengerBalanceIni - amount, "Insuree balance doesn't match");
    assert.equal(currentBalanceEnd, parseFloat(currentBalanceIni) + parseFloat(amount), "Insuree wallet has not been credited");
    

  });


});
