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
        uint256 randomState;
        uint256 matchStartTime;
        uint256 smallBlind;
        uint256 limit;
        uint playerInStep;
        uint verifiedPlayers;
        uint state;
    }

    address private contractOwner;
    uint256 private comission;
    uint256 private nextGameId = 0;
    uint private constant nPlayers = 2;
    
    uint private constant CREATION = 1;
    uint private constant VERIFICATION = 2;
    uint private constant MATCH = 3;
    uint private constant END = 4;

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
        Game memory game = Game({
            owner: msg.sender,
            players: players,
            playersToStateHash: playersToStateHash,
            randomState: 0,
            matchStartTime: 0,
            smallBlind: smallBlind,
            limit: limit,
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
     * in future this method will return playerId, for now, gameOwner has id - 0, and second player - 1
     */
    function joinGame(uint256 gameId, bytes32 randomStateHash) payable public {
        Game storage game = games[gameId];
        // require(StringUtils.equal(game.state, CREATION), "can't join already created game");
        require(game.state == CREATION);
        require(msg.value == comission + 3 * game.smallBlind, "require deposit at least big + small blind");
        require(game.players.length < nPlayers, "can't join to full table");
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
    function escapeGame(uint256 gameId)  payable public {
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
                break;
            }
        }
    }
    
    function revealCards(uint256 gameId, bytes memory cardHash, string memory hash) public {
        // Game storage game = games[gameId];
        // require(StringUtils.equal(game.state, "reveal"));
        // require(game.players[game.playerInStep] == msg.sender);
        
        bytes32 message = prefixed(keccak256(abi.encodePacked(msg.sender, cardHash)));
        require(keccak256(abi.encodePacked(message)) == keccak256(abi.encodePacked(hash)), "bad hash");
        // game.playerInStep = (game.playerInStep + 1) % nPlayers;
    }
    
    
    /// builds a prefixed hash to mimic the behavior of eth_sign.
    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    // function bookTransfer(address receiver, address nftContract, uint256 tokenId) payable public isOwner {
    //     bookedTransfer[keccak256(abi.encodePacked(nftContract, tokenId))] = receiver;
    //     payable(receiver).transfer(comission / 2);
    // }


    // /**
    // * performTransferNFT with confirmation, it needed to not trust our backend
    // **/
    // function performTransferNFT(address sender, address receiver, address nftContract, uint256 tokenId, string memory confirmation) public {
    //     bytes32 nft = keccak256(abi.encodePacked(nftContract, tokenId));
    //     require(bookedTransfer[nft] == msg.sender);
    //     require(confirmationHashes[nft] == keccak256(abi.encodePacked(confirmation)));
    //     Transferable(nftContract).safeTransferFrom(sender, receiver, tokenId);
    // }
}
