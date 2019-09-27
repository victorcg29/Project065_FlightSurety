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
        bool isRegistered;
        bool isRefunded;

    }

    struct Passanger {
        uint256 balance;
        FlightInsurance[] insurances;
    }


    mapping(address => Airline) airlines;      // Mapping for storing airlines
    mapping(bytes32 => Flight) private flights;
    mapping(address => VoteSystem) votes; // Mapping for the votes

    mapping(address => uint256) airlineBalances; // Mapping for the balance of the airlines

    mapping(address => uint256) private authorizedContracts;

    mapping(address => Passanger) private passangers;
    

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event AirlineRegistered(address _address);
    event AirlineFunded(address _address, uint amount);
    event AirlineAproved(address _address);
    event AirlineVoted(address newAirline, address voter);
    event FlightRegistered(address _address, string _flightCode, uint256 _timestamp);


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                    address firstAirline
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        //_registerAirline(firstAirline, true, true, false);
        _registerAirline(firstAirline);
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
                                address wallet           
                            )
                            external
                            requireIsOperational
    {
        //_registerAirline(wallet, isRegistered, isAproved, isFunded);
        _registerAirline(wallet);
    }

    function registerFlight
                            (
                                string flightCode,
                                uint timestamp
                            )
                            external
                            requireIsOperational
    {
        require(airlines[msg.sender].isFunded, "Airline is not funded");
        bytes32 flightKey = _getFlightKey(msg.sender, flightCode, timestamp);
        flights[flightKey] = Flight({
                                airline: msg.sender,
                                isRegistered: true,
                                flightCode: flightCode,
                                timestamp: timestamp,
                                statusCode: 0
                                });

        // Emit event
        emit FlightRegistered(msg.sender, flightCode,  timestamp);
    }



    function _registerAirline
                            (   
                                address wallet
                            )
                            internal
                            requireIsOperational
    {
        require(!airlines[wallet].isRegistered, "Airline already registred");
        /*
        airlines[wallet] = Airline({
                                        isRegistered: isRegistered,
                                        isAproved: isAproved,
                                        isFunded: isFunded
                                    });

        // Emit event
        emit AirlineRegistered(wallet);
        */
        
        if (num_reg_airlines == 0) {
            // Regiter new airline
            airlines[wallet] = Airline({
                                            isRegistered: true,
                                            isAproved: true,
                                            isFunded: false
                                        });
            firstAirline = wallet;
            // Emit events
            emit AirlineRegistered(wallet);
            emit AirlineAproved(wallet);
            
        }
        else if (num_reg_airlines < 4) {
            require(msg.sender == firstAirline, "Only the first registered ariline can register");
            require(airlines[msg.sender].isFunded, "First registered airline is not funded");
            airlines[wallet] = Airline({
                                            isRegistered: true,
                                            isAproved: true,
                                            isFunded: false
                                        });
            // Emit events
            emit AirlineRegistered(wallet);
            emit AirlineAproved(wallet);
        }
        else if (num_reg_airlines >= 4) {
            require(airlines[msg.sender].isFunded, "Airline to add new register is not funded");

            uint256 requiredVotes = num_reg_airlines.div(2) + (num_reg_airlines % 2);
            airlines[wallet] = Airline({
                                            isRegistered: true,
                                            isAproved: false,
                                            isFunded: false
                                        });
            votes[wallet] = VoteSystem({
                                            addresses: new address[](0),
                                            requiredVotes: requiredVotes,
                                            numVotes: 0
                                        });
            // Emit events
            emit AirlineRegistered(wallet);
        }

        num_reg_airlines++;
    }

    function aproveAirline
                        (
                            address airlineWallet,
                            bool aproved
                        )
                        requireIsOperational
    {
        require(airlines[msg.sender].isFunded, "Voting airline is not funded");
        require(!airlines[airlineWallet].isAproved, "Airline already approved");

        bool alreadyVoted = false;
        for (uint c=0; c<votes[airlineWallet].addresses.length; c++)
        {
            if (votes[airlineWallet].addresses[c] == msg.sender) {
                alreadyVoted = true;
                break;
            }
        }

        require(!alreadyVoted, "This airline has already voted");
        votes[airlineWallet].addresses.push(msg.sender);
        if (aproved) {
            votes[airlineWallet].numVotes++;
        }

        emit AirlineVoted(airlineWallet, msg.sender);

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
                            )
                            external
                            payable
    {

    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                )
                                external
                                pure
    {
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                            )
                            external
                            pure
    {
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            (   
                            )
                            public
                            payable
                            requireIsOperational
    {
        require(airlines[msg.sender].isAproved, "Airline is not approved");
        require(!airlines[msg.sender].isFunded, "Airline already funded");
        require(msg.value >= 10 ether, "The funding has to be at least of 10 ether");

        airlines[msg.sender].isFunded = true;
        airlineBalances[msg.sender].add(msg.value);
        // Emit event
        emit AirlineFunded(msg.sender, msg.value);

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

