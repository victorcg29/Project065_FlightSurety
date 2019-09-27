
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

const AIRLINE_FUNDED_AMOUNT = web3.toWei('10', 'ether');

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

        console.log(`Registered: ${result1[0]}, aproved: ${result1[1]}, active: ${result1[2]}`);

        await config.flightSuretyApp.fundAirline({value: AIRLINE_FUNDED_AMOUNT, from: config.firstAirline});

        let result2 = await config.flightSuretyData.getAirlineStatus.call(config.firstAirline);

        console.log(`After funding -> Registered: ${result2[0]}, aproved: ${result2[1]}, active: ${result2[2]}`);

        
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});

        result = await config.flightSuretyData.isAirlineRegistered.call(newAirline);
    }
    catch(e) {

        console.log(`ERROR (register new airline): ${e}`);

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
            console.log(`Registered airines: ${numAirlines}`);
            let newAirline = accounts[a];
            await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    
            let result1 = await config.flightSuretyData.getAirlineStatus.call(newAirline);

            console.log(`Airline ${a} -> Registered: ${result1[0]}, aproved: ${result1[1]}, active: ${result1[2]}`);
        }


        result = await config.flightSuretyData.isAirlineAproved.call(fifthAirline);

    }
    catch(e) {
        console.log(`ERROR: ${e}`);
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
            console.log(`Airline ${j} -> Registered: ${result1[0]}, aproved: ${result1[1]}, active: ${result1[2]}`);

        }

        // Register new airline

        await config.flightSuretyApp.registerAirline(newAirline, {from: accounts[3]});

        let res = await config.flightSuretyData.getAirlineStatus.call(newAirline);

        console.log(`Airline ${newAirline} -> Registered: ${res[0]}, aproved: ${res[1]}, active: ${res[2]}`);

        votes = [true, false, true, true];

        for (let h=1; h<5; h++) {
            // Vote
            let registeredAirline = accounts[h]
            console.log(`AIRLINE to VOTE: ${registeredAirline}`);
            await config.flightSuretyApp.aproveAirline(newAirline, votes[h-1], {from: registeredAirline});

            let result2 = await config.flightSuretyData.getVotesInfo.call(newAirline);
            
            console.log(`Vote ${h} for ${newAirline} -> Required: ${result2[0]}, Aproved: ${result2[1]}`);
        }

        result = await config.flightSuretyData.isAirlineAproved.call(newAirline);
    }
    catch(e) {
        console.log(`ERROR: ${e}`);
    }

    // ASSET
    assert.equal(result, true, "Airline is aproved after multiparty consensus votes");

  });

  

  it('(flight) a funded airline can register a flight', async () => {
      // ARRANGE
      const flightCode = 'ND1309';
      let timestamp = Math.floor(Date.now() / 1000);
      let airlineAddress = accounts[1];

      // ACT
      let flightKey = await config.flightSuretyData.getFlightKey(airlineAddress, flightCode, timestamp);
      console.log(`Flight key: ${flightKey}`);
      let before = await config.flightSuretyData.isFlightRegistered.call(flightKey);
      await config.flightSuretyData.registerFlight(flightCode, timestamp, {from: airlineAddress});
      let after = await config.flightSuretyData.isFlightRegistered.call(flightKey);

      // ASSERT
      assert.equal(before, false, "Flight is already registered");
      assert.equal(after, true, "Fligh not registered");

  });

  it('(passangers) may pay up to 1eth to purchase flight insurance', async () => {

    //ARRANGE

    //ACT

    //ASSERT
  });
 
  

});
