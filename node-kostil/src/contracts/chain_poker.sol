// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import './utils.sol';

/**
 * @title ChainPoker
 * @dev contract designed to organize secured decentralized PVP dro-poker matches
 * each game starts with createGame method, and represents one round,
 * i e for each game will be played the same matches as the number of players(2)
 */
contract ChainPoker {
    
    struct Game {
        address owner;
        address[] players;
        bytes32[] playersToStateHash;
        uint256[] ranks;
        uint8[] cardMasks;
        uint256 money;
        uint256 randomState;
        uint256 matchStartTime;
        uint256 smallBlind;
        uint256 limit;
        uint256 lastBet;
        uint8 playerInStep;
        uint8 verifiedPlayers;
        uint8 count;
        uint8 state;
    }

    address private contractOwner;
    uint256 private comission;
    uint256 private nextGameId = 0;

    uint8 private constant nPlayers = 2;
    uint8 private constant nCards = 52;
    
    uint8 private constant CREATION = 1;
    uint8 private constant NEED_VERIFICATION_AFTER_START = 2;
    uint8 private constant NEED_VERIFICATION_AFTER_CHANGE = 3;
    uint8 private constant MATCH = 4;
    uint8 private constant REVEAL = 5;
    uint8 private constant CLEAR = 6;
    uint8 private constant END = 7;
    uint8 private constant FIRST_TURN = 8;
    uint8 private constant SECOND_TURN = 9;
    uint8 private constant SUPPLY_STATE_AFTER_START = 10;
    uint8 private constant SUPPLY_STATE_AFTER_CHANGE = 11;

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
        uint256[] memory ranks;
        uint8[] memory cardMasks;
        Game memory game = Game({
            owner: msg.sender,
            players: players,
            playersToStateHash: playersToStateHash,
            ranks: ranks,
            cardMasks: cardMasks,
            money: 0,
            randomState: 0,
            matchStartTime: 0,
            smallBlind: smallBlind,
            limit: limit,
            lastBet: 0,
            playerInStep: 0,
            verifiedPlayers: 0,
            count: 0,
            state: SUPPLY_STATE_AFTER_START
        });
        games[gameId]  = game;
        joinGame(gameId, randomStateHash);
    }
    
    /**
     * @dev Join existed game
     * @param gameId is id of game
     * @param randomStateHash is keccak256 hash of random state part proposed by player
     */
    function joinGame(uint256 gameId, bytes32 randomStateHash) payable public returns(uint8 playerId) {
        Game storage game = games[gameId];
        require(game.state == SUPPLY_STATE_AFTER_START, "can't join already created game");
        require(msg.value == comission + 3 * game.smallBlind, "require deposit at least big + small blind");
        require(game.players.length < nPlayers, "can't join to full table");
        playerId = uint8(game.players.length);
        game.players.push(msg.sender);
        game.playersToStateHash.push(randomStateHash);
        game.cardMasks.push(0);
        
        game.verifiedPlayers += 1;
        if (game.verifiedPlayers == nPlayers) {
            game.verifiedPlayers = 0;
            game.state = NEED_VERIFICATION_AFTER_START;
            payable(contractOwner).transfer(nPlayers * comission);
        }
    }
    
    function supplyRandomStateHash(uint256 gameId, bytes32 randomStateHash, uint8 playerId, uint8 cardMask) public {
        Game storage game = games[gameId];
        require(game.state == SUPPLY_STATE_AFTER_CHANGE || game.state == SUPPLY_STATE_AFTER_START, "should have state supply after start or change");
        require(game.players[playerId] == msg.sender);
        require(game.players.length == nPlayers);
        game.playersToStateHash[playerId] = randomStateHash;
        game.cardMasks[playerId] = cardMask;
        game.verifiedPlayers += 1;
        if (game.count == playerId && game.state == SUPPLY_STATE_AFTER_START) {
            game.money += 2 * game.smallBlind;
        }
        if ((game.count + 1) % nPlayers == playerId && game.state == SUPPLY_STATE_AFTER_START) {
            game.money += game.smallBlind;
        }
        if (game.verifiedPlayers == nPlayers) {
            game.verifiedPlayers = 0;
            if (game.state == SUPPLY_STATE_AFTER_START) {
                game.state = NEED_VERIFICATION_AFTER_START;
            }
            if (game.state == SUPPLY_STATE_AFTER_CHANGE) {
                game.state = NEED_VERIFICATION_AFTER_CHANGE;
            }
        }
    }
    

    function verifyPlayerState(uint256 gameId, uint256 randomState, uint8 playerId) public {
        Game storage game = games[gameId];
        require(game.state == NEED_VERIFICATION_AFTER_START || game.state == NEED_VERIFICATION_AFTER_CHANGE, "wrong stage");
        require(playerId == (3 * nPlayers - 1 - game.count - game.verifiedPlayers) % nPlayers, "wrong player");
        require(game.players[playerId] == msg.sender, "wrong msg sender");
        require(game.playersToStateHash[playerId] == keccak256(abi.encodePacked(randomState)), "wrong seed");
        game.randomState += randomState;
        game.verifiedPlayers += 1;
        if (game.verifiedPlayers == nPlayers) {
            game.playerInStep = 0;
            game.state = REVEAL; // SKIP FOR DEBUG
            // if (game.state == NEED_VERIFICATION_AFTER_START) {
            //     game.state = FIRST_TURN;
            // }
            // if (game.state == NEED_VERIFICATION_AFTER_CHANGE) {
            //     game.state = SECOND_TURN;
            // }
        }
    }
    
    function makeBet(uint256 gameId, uint256 playerId) public payable {
        Game storage game = games[gameId];
        require(game.state == FIRST_TURN || game.state == SECOND_TURN, "state is not turn");
        require(game.players[playerId] == msg.sender, "sender is not right player");
        require((game.count + game.playerInStep) % nPlayers == playerId, "it's not your turn");
        require((game.lastBet == msg.value || game.lastBet * 2 <= msg.value) && msg.value <= game.limit, "wrong bet");
        game.money += msg.value;
        game.lastBet = msg.value - game.lastBet;
        game.playerInStep += 1;
        if (game.lastBet != 0 && game.playerInStep == nPlayers) {
            game.playerInStep = 0;
            return;
        }

        if (game.playerInStep == nPlayers) {
            game.lastBet = 0;
            game.playerInStep = 0;
            game.verifiedPlayers = 0;
            if (game.state == FIRST_TURN) {
                game.state = SUPPLY_STATE_AFTER_CHANGE;
            }
            if (game.state == SECOND_TURN) {
                game.state = REVEAL;
            }
        }
    }
    
    
    function revealCards(uint256 gameId, bytes memory signature, uint256 claimedHand, uint8 claimedCombination, uint8 playerId) public {
        Game storage game = games[gameId];
        require(game.state == REVEAL, "expect reveal stage");
        uint8 currentPlayer = (game.count + game.playerInStep) % nPlayers;
        require(currentPlayer == playerId);
        require(game.players[currentPlayer] == msg.sender);
        bytes32 message = prefixed(keccak256(abi.encodePacked(game.randomState + playerId)));
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);
        // require(ecrecover(message, v, r, s) == msg.sender, "bad signer");
        uint8[5] memory cardIds = parseCards(v, r, s);
        require(PokerUtils.checkClaimedHand(claimedHand, cardIds));
        require(PokerUtils.checkClaimedCombination(claimedHand, claimedCombination));
        game.ranks[playerId] = PokerUtils.calcHandRank(claimedHand, claimedCombination);
        game.playerInStep = (game.playerInStep + 1) % nPlayers;
        if (game.playerInStep == game.count) {
            game.state = CLEAR;
        }
    }
    
    function requestBank(uint256 gameId) public payable {
        Game storage game = games[gameId];
        require(game.state == CLEAR, "expect clear stage");
        uint256 maxRank = 0;
        address playerWithMaxRank;
        for(uint8 i = 0;i < game.players.length; ++i) {
            if (game.ranks[i] > maxRank) {
                maxRank = game.ranks[i];
                playerWithMaxRank = game.players[i];
            }
        }
        game.count += 1;
        if (game.count == nPlayers) {
            game.state = END;
        } else {
            game.verifiedPlayers = 0;
            game.state = CREATION;
        }
        payable(playerWithMaxRank).transfer(game.money);
    }
    
    function parseCards(uint8 v, bytes32 r, bytes32 s) internal pure returns (uint8[5] memory) {
        uint256 seed = 3 * uint256(s) + 5 * uint256(r) + 7 * v;
        uint8[5] memory cardIds;
        for(uint8 i = 0;i < 5; ++i) {
            cardIds[i] = uint8(seed % nCards);
            seed = 31 * seed + 13;
        }
        return cardIds;
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
