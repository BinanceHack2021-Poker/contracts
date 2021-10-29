// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import '@openzeppelin/contracts/utils/Strings.sol';

/**
 * @title ChainHoldem
 * @dev contract designed to organize secured decentralized PVP holdem poker matches
 * each game starts with createGame method, and represents one round,
 * i e for each game will be played the same matches as the number of players(2)
 */
contract ChainHoldem {
    
    struct Game {
        address owner;
        address[] players;
        bytes32[] playersToStateHash;
        uint256[] claimedHands;
        uint8[] claimedCombinations;
        uint8[] board;
        uint256 randomState;
        uint256 matchStartTime;
        uint256 smallBlind;
        uint256 limit;
        uint8 firstPlayer;
        uint8 playerInStep;
        uint8 verifiedPlayers;
        uint8 state;
    }

    address private contractOwner;
    uint256 private comission;
    uint256 private nextGameId = 0;
    uint8 private constant nPlayers = 2;
    uint8 private constant nCards = 52;
    
    uint8 private constant CREATION = 1;
    uint8 private constant VERIFICATION = 2;
    uint8 private constant MATCH = 3;
    uint8 private constant REVEAL = 4;
    uint8 private constant CLEAR = 5;
    uint8 private constant END = 6;

    uint8 private constant HIGH_CARD = 0;
	uint8 private constant ONE_PAIR = 1;
	uint8 private constant TWO_PAIR = 2;
	uint8 private constant THREE_OF_A_KIND = 3;
	uint8 private constant STRAIGHT = 4;
	uint8 private constant FLUSH = 5;
	uint8 private constant FULL_HOUSE = 6;
	uint8 private constant FOUR_OF_A_KIND = 7;
	uint8 private constant STRAIGHT_FLUSH = 8;

    modifier isOwner(address owner) {
        require(msg.sender == owner, "Caller is not owner");
        _;
    }

    mapping(uint256 => Game) private games;

    /**
     * @dev Set contract deployer as owner and comission
     */
    constructor(uint256 _comission) {
        contractOwner = msg.sender; // 'msg.sender' is sender of current call, contract deployer for a constructor
        comission = _comission;
    }

    /**
     * @dev Change contract owner
     * @param newOwner address of new owner
     */
    function changeOwner(address newOwner) public isOwner(contractOwner) {
        contractOwner = newOwner;
    }

    /**
     * @dev Create new game and join owner to it
     * @param smallBlind is size of small blind (in wei)
     * @param limit is size of limit for each bet (in wei)
     * @param randomStateHash is keccak256 hash of random state part proposed by player
     * returns gameId is id for created game
     */
    function createGame(uint256 smallBlind, uint256 limit, bytes32 randomStateHash) payable public returns (uint256 gameId) {
        require(2 * smallBlind <= limit);
        require(msg.value == comission + 3 * smallBlind, "require deposit equals to big + small blind");
        gameId = nextGameId++;
        address[] memory players;
        bytes32[] memory playersToStateHash;
        uint256[] memory claimedHands;
        uint8[] memory claimedCombinations;
        uint8[] memory board;
        Game memory game = Game({
            owner: msg.sender,
            players: players,
            playersToStateHash: playersToStateHash,
            claimedHands: claimedHands,
            claimedCombinations: claimedCombinations,
            board: board,
            randomState: 0,
            matchStartTime: 0,
            smallBlind: smallBlind,
            limit: limit,
            firstPlayer: 0,
            playerInStep: 0,
            verifiedPlayers: 0,
            state: CREATION
        });
        games[gameId]  = game;
        joinGame(gameId, randomStateHash);
    }
    
    /**
     * @dev Join existed game
     * @param gameId is id of game
     * @param randomStateHash is keccak256 hash of random state part proposed by player
     */
    function joinGame(uint256 gameId, bytes32 randomStateHash) payable public returns(uint playerId) {
        Game storage game = games[gameId];
        require(game.state == CREATION, "can't join already created game");
        require(msg.value == comission + 3 * game.smallBlind, "require deposit at least big + small blind");
        require(game.players.length < nPlayers, "can't join to full table");
        playerId = game.players.length;
        game.players.push(msg.sender);
        game.playersToStateHash.push(randomStateHash);
        if (game.players.length == nPlayers) {
            game.state = VERIFICATION;
        }
    }
    
    /**
     * @dev Escape from created game(which not started yet) and destroy it, could be called only by owner
     * @param gameId is id of game
     */
    function escapeGame(uint256 gameId) payable public {
        Game storage game = games[gameId];
        require(game.state == CREATION, "can't escape from started game");
        require(game.owner == msg.sender);
        payable(msg.sender).transfer(comission + 3 * game.smallBlind);
        game.state = END;
    }
    

    function verifyPlayerState(uint256 gameId, uint256 randomState) external {
        Game storage game = games[gameId];
        require(game.state == VERIFICATION);
        for (uint p = 0; p < game.players.length; p++) {
            if (game.players[p] == msg.sender) {
                require(game.playersToStateHash[p] == keccak256(abi.encodePacked(randomState)));
                game.randomState += randomState;
                game.verifiedPlayers += 1;
                if (game.verifiedPlayers == 2) {
                    game.playerInStep = 0;
                    game.matchStartTime =  block.timestamp;
                    game.state = MATCH;
                }
                return;
            }
        }
        require(false, "unreachable code");
    }
    
    function revealCards(uint256 gameId, bytes memory signature, uint256 claimedHand, uint8 claimedCombination) public {
        Game storage game = games[gameId];
        require(game.state == REVEAL, "expect reveal stage");
        require(game.players[game.playerInStep] == msg.sender);
        bytes32 message = prefixed(keccak256(abi.encodePacked(game.randomState + game.playerInStep)));
        
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);
        require(ecrecover(message, v, r, s) == msg.sender, "bad signer");
        (uint8 card1Id, uint8 card2Id) = parseCards(v, r, s);
        require(checkClaimedHand(claimedHand, card1Id, card2Id, game.board));
        require(checkClaimedCombination(claimedHand, claimedCombination));
        game.claimedHands[game.playerInStep] = claimedHand;
        game.claimedCombinations[game.playerInStep] = claimedCombination;
        game.playerInStep = (game.playerInStep + 1) % nPlayers;
        if (game.playerInStep == game.firstPlayer) {
            game.state = CLEAR;
        }
    }
    
    function checkNCardsEqual(uint256 hand, uint8 nCards, uint8 offset) pure internal returns(bool) {
        uint8 goldenCardId = nCards;
        for(uint i = 0; i < 5; ++i) {
            uint8 card = uint8(hand % nCards);
            uint8 cardId = card / 4;
            hand = hand / nCards;
            if (i >= offset && i < offset + nCards) {
                if (goldenCardId == nCards) {
                    goldenCardId = cardId;
                    continue;
                }
                if (goldenCardId != cardId) {
                    return false;
                }
            }
        }
        return true;
    }
    
    function checkFlush(uint256 hand) pure internal returns(bool)  {
        uint8 goldenType = nCards;
        for(uint i = 0; i < 5; ++i) {
            uint8 card = uint8(hand % nCards);
            uint8 cardType = card % 4;
            hand = hand / nCards;
            if (goldenType == nCards) {
                goldenType = cardType;
                continue;
            }
            if (goldenType != cardType) {
                return false;
            }
        }
        return true;
    }
    
    
    function checkStraight(uint256 hand) pure internal returns(bool)  {
        uint8 lastId = nCards;
        for(uint i = 0; i < 5; ++i) {
            uint8 card = uint8(hand % nCards);
            uint8 cardId = card / 4;
            hand = hand / nCards;
            if (i > 0) {
                if (cardId + 1 != lastId) {
                    return false;
                }
            }
            lastId = cardId;
        }
        return true;
    }
    
    
    function checkClaimedCombination(uint256 claimedHand, uint8 claimedCombination) internal pure returns(bool) {
        if (claimedCombination == HIGH_CARD) {
            return true;
        }
        if (claimedCombination == ONE_PAIR) {
            return checkNCardsEqual(claimedHand, 2, 0);
        }
        
        if (claimedCombination == TWO_PAIR) {
            return checkNCardsEqual(claimedHand, 2, 0) && checkNCardsEqual(claimedHand, 2, 2);
        }
        
        if (claimedCombination == THREE_OF_A_KIND) {
            return checkNCardsEqual(claimedHand, 3, 0);
        }
        
        if (claimedCombination == STRAIGHT) {
            return checkStraight(claimedHand);
        }
        
        if (claimedCombination == FLUSH) {
            return checkFlush(claimedHand);
        }
        
        if (claimedCombination == FULL_HOUSE) {
            return checkNCardsEqual(claimedHand, 3, 0) && checkNCardsEqual(claimedHand, 2, 3);
        }
        
        if (claimedCombination == FOUR_OF_A_KIND) {
            return checkNCardsEqual(claimedHand, 4, 0);
        }
        
        if (claimedCombination == STRAIGHT_FLUSH) {
            return checkStraight(claimedHand) && checkFlush(claimedHand);
        }
        return false;
    }
    
    function checkClaimedHand(uint256 claimedHand, uint8 card1Id, uint8 card2Id, uint8[] memory board) internal pure returns(bool) {
        for(uint i = 0; i < 5; ++i) {
            uint8 clamedCard = uint8(claimedHand % nCards);
            claimedHand = claimedHand / nCards;
            if (clamedCard != card1Id && clamedCard != card2Id) {
                bool foundEq = false;
                for(uint j = 0;j < board.length; ++j) {
                    if (clamedCard == board[j]) {
                        foundEq = true;
                        break;
                    }
                }
                if(!foundEq) {
                    return false;
                }
            }
        }
        
        return true;
    }


    function cardId2Obj(uint8 cardId) internal pure returns (uint8, uint8) {
        uint8 cardType = cardId % 4;
        uint8 cardOrder = cardId / 4;
        return (cardType, cardOrder);
    }
    
    function parseCards(uint8 v, bytes32 r, bytes32 s) internal pure returns (uint8, uint8) {
        uint8 card1Id = uint8((3 * uint256(s) + 5 * uint256(r) + 7 * v) % nCards);
        uint8 card2Id = uint8((11 * uint256(s) + 13 * uint256(r) + 17 * v) % nCards);
        return (card1Id, card2Id);
    }
    
    /// signature methods.
    function splitSignature(bytes memory sig)
        internal
        pure
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        require(sig.length == 65);

        assembly {
            // first 32 bytes, after the length prefix.
            r := mload(add(sig, 32))
            // second 32 bytes.
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes).
            v := byte(0, mload(add(sig, 96)))
        }

        return (v, r, s);
    }

    
    /// builds a prefixed hash to mimic the behavior of eth_sign.
    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }
}
