pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    uint256  num_reg_airlines = 0;
    uint256 insuranceId = 0;
    address private firstAirline;                                       // First registered Airline

    struct Airline {
        bool isRegistered;
        bool isAproved;
        bool isFunded;
    }

    struct VoteSystem {
        address[] addresses;
        uint256 numVotes;
        uint256 requiredVotes;
    }

    struct Flight  {
        address airline;
        string flightCode;
        uint256 timestamp;
        uint8 statusCode;
        bool isRegistered; 
    }

    struct FlightInsurance {
        address airline;
        string flightCode;
        bytes32 flightKey;
        uint256 amountPayed;
        uint256 amountToPay;
        bool isRegistered;
        bool isRefunded;

    }

    struct Passanger {
        uint256 balance;
        bool isRegistered;
        uint256[] insuranceIds;
    }


    mapping(address => Airline) airlines;      // Mapping for storing airlines
    mapping(bytes32 => Flight) private flights;
    mapping(address => VoteSystem) votes; // Mapping for the votes

    mapping(address => uint256) airlineBalances; // Mapping for the balance of the airlines

    mapping(address => uint256) private authorizedContracts;

    mapping(address => Passanger) private passengers;
    mapping(uint256 => FlightInsurance) private insurances;
    

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event AirlineRegistered(address _address);
    event AirlineFunded(address _address, uint amount);
    event AirlineAproved(address _address);
    event AirlineVoted(address newAirline, address voter);
    event FlightRegistered(address _address, string _flightCode, uint256 _timestamp);
    event VotingRoundAdded(address _address);
    event InsurancePurchased(address passenger, address airline, string flightCode, uint amountPayed);
    event FlightStatusUpdated(address _address, string _flightCode, uint256 _timestamp, uint _statusCode);
    event FlightInsuranceUpdated(uint insuranceId, address airline, string flightCode, uint amountToPay);
    event InsuranceCredited(address passenger, string flightCode, uint amount);
    event InsureeWithdrawn(address passenger, uint amount);

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                    address airline
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        _registerAirline(airline, true, true, false);
        firstAirline = airline;
        //_registerAirline(firstAirline);
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireIsCallerAuthorized()
    {
        require(authorizedContracts[msg.sender] == 1, "Caller is not contract owner");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

    function isAirlineRegistered
                                (
                                    address airline
                                )
                                external
                                requireIsOperational
                                returns(bool)    
    {
        return airlines[airline].isRegistered;
    }

    function isAirlineAproved
                            (
                                address airline
                            )
                            external
                            requireIsOperational
                            returns(bool)
    {
        return airlines[airline].isAproved;
    }

    function isFlightRegistered
                                (
                                    bytes32 flightKey
                                )
                                external
                                requireIsOperational
                                returns(bool)
    {
        return flights[flightKey].isRegistered;
    }

    function isPassengerRegistered
                                    (
                                        address passenger
                                    )
                                    external
                                    requireIsOperational
                                    returns(bool)
    {
        return passengers[passenger].isRegistered;
    }

    function authorizeCaller
                            (
                                address contractAddress
                            )
                            external
                            requireContractOwner
    {
        authorizedContracts[contractAddress] = 1;
    }

    function getAirlineStatus
                            (
                                address airline
                            )
                            external
                            requireIsOperational
                            returns
                                    (
                                        bool isRegistered,
                                        bool isAproved,
                                        bool isFunded                                    
                                    )
    {
        isRegistered = airlines[airline].isRegistered;
        isAproved = airlines[airline].isAproved;
        isFunded = airlines[airline].isFunded;

        return (
            isRegistered,
            isAproved,
            isFunded
        );
    }

    function getFlightStatus
                            (
                                address airline,
                                string flightCode,
                                uint256 timestamp
                            )
                            returns(uint8)
    {
        bytes32 flightKey = _getFlightKey(airline, flightCode, timestamp);
        return flights[flightKey].statusCode;
    }

    function getFirstAirline()
                                external
                                requireIsOperational
                                returns(address)
    {
        return firstAirline;
    }


    function isInsuranceFromFlight
                                    (
                                        bytes32 flightKey,
                                        uint index
                                    )
                                    external
                                    requireIsOperational
                                    returns(bool)
    {
        return (insurances[index].flightKey == flightKey);
    }

    function getNumInsurances()
                                external
                                requireIsOperational
                                returns(uint)
    {
        return insuranceId;
    }

    function isPassengerEligibleForPayout
                                        (
                                            address passenger
                                        )
                                        external
                                        constant
                                        requireIsOperational
                                        returns(bool)
    {
        bool isEligible = false;
        for (uint i=0; i < passengers[passenger].insuranceIds.length; i++) {
            uint insuranceId = passengers[passenger].insuranceIds[i];
            if (insurances[insuranceId].amountToPay > 0)
            {
                isEligible = true;
                break;
            }
        }
        return isEligible;
    }
    function getInsurancePayedAmount
                                    (
                                        uint insuranceId
                                    )
                                    external
                                    requireIsOperational
                                    returns(uint)
    {
        return insurances[insuranceId].amountPayed;
    }

    function getPassengerBalance
                                (
                                    address passenger
                                )
                                external
                                constant
                                requireIsOperational
                                returns(uint)
    {
        return passengers[passenger].balance;
    }

    function isAirlineFunded
                            (
                                address airline
                            )
                            external
                            requireIsOperational
                            returns(bool)
    {
        return airlines[airline].isFunded;

    }

    function getNumRegAirlines()
                                external
                                requireIsOperational
                                returns(uint)
    {
        return num_reg_airlines;
    }

    function getVotesInfo
                        (
                            address airline
                        )
                        external
                        requireIsOperational
                        returns
                                (
                                    uint256 requiredVotes,
                                    uint256 approvedVotes
                                )
    {
        requiredVotes = votes[airline].requiredVotes;
        approvedVotes = votes[airline].numVotes;

        return(
            requiredVotes,
            approvedVotes
        );
    }

    function getInsuranceInfo
                            (
                                address passenger,
                                string flightCode
                            )
                            external
                            requireIsOperational
                            returns
                                    (
                                        address airline,
                                        uint256 amount,
                                        uint256 amountToPay,
                                        bool isRegistered,
                                        bool isRefunded
                                    )
    {

        for(uint i=0; i < passengers[passenger].insuranceIds.length; i++) {
            uint insuranceId = passengers[passenger].insuranceIds[i];
            if (keccak256(bytes(insurances[insuranceId].flightCode)) == keccak256(bytes(flightCode))) {
                airline = insurances[insuranceId].airline;
                amount = insurances[insuranceId].amountPayed;
                amountToPay = insurances[insuranceId].amountToPay;
                isRegistered = insurances[insuranceId].isRegistered;
                isRefunded = insurances[insuranceId].isRefunded;
                
                break;
            }
        }

        return
                (
                    airline,
                    amount,
                    amountToPay,
                    isRegistered,
                    isRefunded
                );
    }

    function isEligibleToWithdraw
                                (
                                    address passenger,
                                    uint amount
                                )
                                external
                                constant
                                requireIsOperational
                                returns(bool)
    {
        return (passengers[passenger].balance >= amount);
    }

    function getAirlineBalane
                            (
                                address airline
                            )
                            external
                            constant
                            requireIsOperational
                            returns(uint)
    {
        return airlineBalances[airline];
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline
                            (
                                address wallet,
                                bool isRegistered,
                                bool isAproved,
                                bool isFunded        
                            )
                            external
                            requireIsOperational
    {
        _registerAirline(wallet, isRegistered, isAproved, isFunded);
       // _registerAirline(wallet);
    }

    function registerFlight
                            (
                                string flightCode,
                                uint timestamp,
                                address airline
                            )
                            external
                            requireIsOperational
    {
        
        
        bytes32 flightKey = _getFlightKey(airline, flightCode, timestamp);
        flights[flightKey] = Flight({
                                airline: airline,
                                isRegistered: true,
                                flightCode: flightCode,
                                timestamp: timestamp,
                                statusCode: 0
                                });

        // Emit event
        emit FlightRegistered(msg.sender, flightCode,  timestamp);
        
    }

    function updateFlightStatus
                                (
                                    bytes32 flightKey,
                                    uint8 status
                                )
                                external
                                view
                                requireIsOperational
    {
        flights[flightKey].statusCode = status;
        emit FlightStatusUpdated(flights[flightKey].airline, flights[flightKey].flightCode, flights[flightKey].timestamp, status);
    }


    function addVotingRound
                            (
                                address airline,
                                uint requiredVotes
                            )
                            external
                            requireIsOperational
    {
        
        votes[airline] = VoteSystem({
                                        addresses: new address[](0),
                                        numVotes: 0,
                                        requiredVotes: requiredVotes
                                    });
        emit VotingRoundAdded(airline);
        
    }

    function updateFlightInsurance
                                    (
                                        uint insuranceId,
                                        uint amountToPay
                                    )
                                    external
                                    requireIsOperational
    {
        insurances[insuranceId].amountToPay = amountToPay;
        emit FlightInsuranceUpdated(insuranceId, insurances[insuranceId].airline, insurances[insuranceId].flightCode, insurances[insuranceId].amountToPay);
    }


    function _registerAirline
                            (   
                                address wallet,
                                bool isRegistered,
                                bool isAproved,
                                bool isFunded
                            )
                            internal
                            requireIsOperational
    {   
        airlines[wallet] = Airline({
                                        isRegistered: isRegistered,
                                        isAproved: isAproved,
                                        isFunded: isFunded
                                    });

        num_reg_airlines++;
        // Emit event
        emit AirlineRegistered(wallet);
        if (isAproved) {
            emit AirlineAproved(wallet);
        }
    }

    function aproveAirline
                        (
                            address airlineWallet,
                            bool aproved,
                            address voter
                        )
                        external
                        requireIsOperational
    {
        //equire(airlines[msg.sender].isFunded, "Voting airline is not funded");
        //require(!airlines[airlineWallet].isAproved, "Airline already approved");

        bool alreadyVoted = false;
        for (uint c=0; c<votes[airlineWallet].addresses.length; c++)
        {
            if (votes[airlineWallet].addresses[c] == voter) {
                alreadyVoted = true;
                break;
            }
        }

        require(!alreadyVoted, "This airline has already voted");
        votes[airlineWallet].addresses.push(voter);
        if (aproved) {
            votes[airlineWallet].numVotes++;
        }

        emit AirlineVoted(airlineWallet, voter);

        if (votes[airlineWallet].numVotes >= votes[airlineWallet].requiredVotes) {
            airlines[airlineWallet].isAproved = true;
            // Delete register from the votes variable
            //delete votes[airlineWallet];
            // Emit events
            emit AirlineAproved(airlineWallet);
        }
        

    }

   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (
                                bytes32 flightKey,
                                address passenger,
                                uint amount                            
                            )
                            external
                            requireIsOperational
    {
        string flightCode = flights[flightKey].flightCode;
        address airline = flights[flightKey].airline;
        passengers[passenger] = Passanger({
                                            isRegistered: true,
                                            balance: 0,
                                            insuranceIds: new uint256[](0)
                                        });
        insurances[insuranceId] = FlightInsurance({
                                                    airline: airline,
                                                    flightCode: flightCode,
                                                    flightKey: flightKey,
                                                    amountPayed: amount,
                                                    amountToPay: 0,
                                                    isRegistered: true,
                                                    isRefunded: false
                                                });
        passengers[passenger].insuranceIds.push(insuranceId);
        insuranceId++;
        emit InsurancePurchased(passenger, airline, flightCode, amount);

    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                    address passenger
                                )
                                external
                                requireIsOperational
    {
        for (uint i=0; i < passengers[passenger].insuranceIds.length; i++) {
            uint insuranceId = passengers[passenger].insuranceIds[i];
            uint amount = insurances[insuranceId].amountToPay;
            require(airlineBalances[insurances[insuranceId].airline] >= amount, "Airline has not enought funds to pay");
            insurances[insuranceId].isRefunded = true;
            airlineBalances[insurances[insuranceId].airline] = airlineBalances[insurances[insuranceId].airline].sub(amount);
            passengers[passenger].balance = passengers[passenger].balance.add(amount);

            emit InsuranceCredited(passenger, insurances[insuranceId].flightCode, amount);
        }


    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                                address passenger,
                                uint amount
                            )
                            external
                            payable
                            requireIsOperational
    {
        passengers[passenger].balance = passengers[passenger].balance.sub(amount);
        passenger.transfer(amount);
        emit InsureeWithdrawn(passenger, amount);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fundAirline
                            (
                                address airline,
                                uint amount
                            )
                            external
                            requireIsOperational
    {
        airlines[airline].isFunded = true;
        airlineBalances[airline] = airlineBalances[airline].add(amount);
        // Emit event
        emit AirlineFunded(airline, amount);

    }

    function fund
                            (   
                            )
                            public
                            payable
    {
    }

    function getFlightKey
                        (
                            address airline,
                            string flight,
                            uint256 timestamp
                        )
                        external
                        view
                        requireIsOperational
                        returns(bytes32)
    {
        return _getFlightKey(airline, flight, timestamp);
    }

    function _getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        internal
                        pure
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
    {
        fund();
    }


}

