// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    /* Events */
    event EnteredRaffe(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (entranceFee, interval, vrfCoordinator, gasLane, subscriptionId, callbackGasLimit,,) =
            helperConfig.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    // enterRaffle //
    function testRaffleRevertsWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);
        // Act // Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughETHForFee.selector);
        raffle.enterRaffle{value: 0.001 ether}();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        raffle.enterRaffle{value: entranceFee}();

        // Assert
        address playerRecoreded = raffle.getPlayer(0);
        assert(playerRecoreded == PLAYER);
    }

    function testEmitEventOnEntrance() public {
        // Arrange
        vm.prank(PLAYER);
        // Act // Assert
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffe(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterWhileRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    /////////////////
    // checkUpkeep //
    /////////////////

    function testCheckUpKeepReturnsFalseIfIthasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfRaffleNotOpen() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        raffle.performUpkeep("");

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfEnoughTimeHasntPassed() public {
        // Arrange
        uint256 raffleInterval = raffle.getInterval();
        vm.warp(block.timestamp + raffleInterval - 1);
        vm.roll(block.number + 1);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsTrueWhenParametersAreGood() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded);
    }

    ///////////////////
    // performUpkeep //
    ///////////////////

    function testPerformUpKeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // Act
        raffle.performUpkeep("");
    }

    function testPerformUpKeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0;
        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, raffleState)
        );
        raffle.performUpkeep("");
    }

    modifier enteredRaffleAndTimePassed() {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsEvent() public enteredRaffleAndTimePassed {
        // Arrange

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emit requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 requestId = entries[1].topics[0];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }

    /////////////////////////
    // fullfillRandomWords //
    /////////////////////////

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFullfillRandomWordsCanOnlyBeCalledAfterPerfomUpkeep(uint256 randomrequestID)
        public
        enteredRaffleAndTimePassed
        skipFork
    {
        // Arrange
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(randomrequestID, address(raffle));
        // Act

        // Assert
    }

    function testFullfillRandomWordsPicksWinnerResetsAndSendsMoney() public enteredRaffleAndTimePassed skipFork {
        // Arrange

        uint256 additionalPlayers = 5;
        uint256 startingIndex = 1;

        for (uint256 i = startingIndex; i < startingIndex + additionalPlayers; i++) {
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        // Act

        uint256 prize = entranceFee * raffle.getPlayersAmount();
        vm.recordLogs();
        raffle.performUpkeep(""); // emit requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[0].topics[2];

        uint256 previousTimestamp = raffle.getLastTimestamp();

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        assert(uint256(raffle.getRaffleState()) == 0);
        assert(raffle.getLatestWinner() != address(0));
        assert(previousTimestamp < raffle.getLastTimestamp());
        console.log("Winner Balance: ", address(raffle.getLatestWinner()).balance);
        console.log("expected balance: ", STARTING_USER_BALANCE + prize - entranceFee);
        console.log("prize: ", prize);
        assert(address(raffle.getLatestWinner()).balance == STARTING_USER_BALANCE + prize - entranceFee);
    }
}
