//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

// Use openzeppelin to inherit battle-tested implementations (ERC20, ERC721, etc)
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Address.sol";


/**
 * A simple billboard smartcontract, where a message state variable is for sale! Folks who mint the NFT 
 * opt in to be advertised to, and so are entitled to a cut from the ad revenue
 * users will see ads in their wallet, embedded in their app, or posted on social media Źike Warpcast
 * 
 * TODOS for V2
 *  - Figure out refund for ads that are replaced too quickly that doesn't encourage too much sybling
 *  - 	- Idea: 10% Protocol Fee paid regardless, small window (1 hour?)
 *  - Figure out some friction for Sybiling audience growth
 * @author zherring
 */
contract AdFrame is ERC721Enumerable, Ownable {

	// state variables
	uint256 public protocolFee = 10; // percentage protocol takes
	uint256 public protocolRevenue = 0; // protocol's revenue 

	// Epoch data, where I store the number of NFTs minted (will limit withdraws to NFT ids >= total minted) and the amount paid to track how much they're owed
	struct epochData {
		uint256 nftsMinted;
		uint256 amtOwed;
	}

	// storing epoch data
	mapping(uint256 => epochData) public epochs;
	uint256 public currentEpoch = 0;

    // Mapping to track whether a specific NFT ID has been withdrawn for a specific epoch
	mapping(uint256 => mapping(uint256 => bool)) private hasWithdrawn;


	// NFT variables for creating and tracking NFTs
	using Counters for Counters.Counter;
	Counters.Counter public _tokenIds;
	Counters.Counter private _activeTokens; // Active (non-burned) token count
	//// URI for all tokens, unnecessary to have unique URI for each NFT since they all share the same billboard message
	string private _commonURI;

	// Storing NFT withdrawal data
	mapping(uint256 => uint256[]) private nftIdWithdraws;
	
	// Billboard Variables
	string public billboard = "This Space for Sale";
	string public billboardURL = "https://adframe.xyz";
	uint256 public basePrice = 270000000000000;
	uint256 public lastPrice = basePrice;
	uint256 public lastUpdateTime;
	uint256 public decreaseRate = 270000000000;
	uint256 public increaseRate = 2700000000000;


    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     *
     * Reverts if the token ID does not exist. May return an empty string.
     *
     * This function is a required override of ERC721's `tokenURI` function.
     *
     * @param tokenId uint256 ID of the token to query.
     * @return string memory URI for the token.
     */
	function tokenURI(uint256 tokenId) public view override returns (string memory) {
			require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
			return _commonURI;
    }
    /**
     * @dev Emitted when the billboard message and URL are changed.
     *
     * @param billboardSetter The address that changed the billboard.
     * @param newBillboard The new billboard message.
     * @param newBillboardURL The new URL for the billboard.
     * @param value The value sent with the change, which is used to calculate the protocol fee.
     */
	event BillboardChange(
		address indexed billboardSetter,
		string newBillboard,
		string newBillboardURL,
		uint256 value
	);

    /**
     * @dev Emitted when a withdrawal is successful.
     *
     * @param epochNumber The epoch number for which the withdrawal was made.
     * @param nftId The ID of the NFT for which the withdrawal was made.
     * @param amountOwed The amount withdrawn by the NFT owner.
     */
    event WithdrawalSuccessful(uint256 indexed epochNumber, uint256 indexed nftId, uint256 amountOwed);
    /**
     * @dev Emitted when an epoch is updated.
     *
     * @param epochIndex The index of the updated epoch.
     * @param nftsMinted The number of NFTs minted in the updated epoch.
     * @param amtOwed The amount owed to each NFT owner in the updated epoch.
     */
    event EpochUpdated(uint256 indexed epochIndex, uint256 nftsMinted, uint256 amtOwed);

    // initiate the smart contract
	constructor(string memory initialURI) ERC721("BillboardNFT", "BBNFT") {
        lastUpdateTime = block.timestamp;
				_commonURI = initialURI;
    }

	/**
	 * @dev Function that allows anyone to change the state variable "billboard" and billboardURL of the contract.
	 *
	 * @param _newBillboardMessage (string memory) - new billboard message to save on the contract
	 * @param _newBillboardURL (string memory) - not required
	 */
	function setBillboard(string memory _newBillboardMessage, string memory _newBillboardURL ) public payable {

		uint256 adjustedPrice = getAdjustedPrice();
		require(msg.value >= adjustedPrice, "Insufficient funds sent");


		// Change state variables
		billboard = _newBillboardMessage;
		billboardURL = _newBillboardURL;
		lastPrice = msg.value + increaseRate;
		lastUpdateTime = block.timestamp;

		uint256 fee = msg.value * protocolFee / 100;
		protocolRevenue += fee;
		uint256 remainder = msg.value - fee;
		// create a new epoch entry
		currentEpoch +=1; // move to next epoch

		// Calculate the amount owed per active (non-burned) NFT, handling division by zero by setting amtOwed to 0 if no NFTs have been minted
        uint256 currentActiveTokens = _activeTokens.current();
        // Calculate the amount owed per NFT, handling division by zero by setting amtOwed to 0 if no NFTs have been minted
        uint256 amtOwedPerNFT;
        if (currentActiveTokens > 0) {
            amtOwedPerNFT = remainder / currentActiveTokens;
        } else {
            amtOwedPerNFT = 0;
        }

		// Store the new epoch data
        uint256 totalNFTsMinted = _tokenIds.current();
        epochs[currentEpoch] = epochData(totalNFTsMinted, amtOwedPerNFT);
		emit EpochUpdated(currentEpoch, totalNFTsMinted, amtOwedPerNFT);
		// emit: keyword used to trigger an event
		emit BillboardChange(msg.sender, _newBillboardMessage, _newBillboardURL, msg.value);
	}

    /**
     * @dev Calculates the adjusted price for setting a new billboard message.
     * The adjusted price decreases over time since the last update but cannot fall below the base price.
     * This ensures the price dynamically reflects demand while maintaining a minimum value.
     *
     * @return uint256 The adjusted price for setting a new billboard message.
     */
    function getAdjustedPrice() public view returns (uint256) {
        // Calculate the time elapsed since the last billboard update
        uint256 timeElapsed = block.timestamp - lastUpdateTime;
        
        // Calculate the amount by which the price should decrease based on the elapsed time
        uint256 decreaseAmount = timeElapsed * decreaseRate;
        
        // Initialize the variable to store the adjusted price
        uint256 adjustedPrice;
        
        // If the last price minus the decrease amount is greater than the base price,
        // set the adjusted price to this new value. Otherwise, set it to the base price.
        if (lastPrice > decreaseAmount) {
            adjustedPrice = lastPrice - decreaseAmount;
        } else {
            // Ensures the adjusted price does not fall below the base price
            adjustedPrice = basePrice;
        }

        // Return the calculated adjusted price
        return adjustedPrice;
    }

    /**
     * @dev Mints a new NFT to the caller's address if they do not already own one. 
     * This function is designed to ensure that each address can only mint one NFT to participate in the billboard advertisement revenue sharing. 
     * Upon minting, the NFT's token ID is incremented, and the active token count is updated to reflect the new total. 
     * Additionally, the price for the next billboard message update is increased by the specified increase rate to adjust for the new NFT minted.
     *
     * Requirements:
     * - The caller must not already own an NFT minted by this contract to prevent Sybil attacks and ensure fair distribution.
     *
     * Emits a `Transfer` event as defined in the ERC721 standard, indicating the minting of a new NFT to the caller's address.
     *
     * Note: The function includes a safeguard against Sybil attacks by limiting minting to one NFT per address. However, this measure may not fully prevent determined attackers from circumventing the restriction through the use of multiple addresses.
     */
    function mintNFT() public {
                // @zherring someone could simply sybil the contract and get around this require statement. It is a medium to High severity issue. 
                // this is to limit NFT mints to 1 per address 
                require(balanceOf(msg.sender) == 0, "Address already owns an NFT");

                // incrementing token ID
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId);

                // increment active token counter
                _activeTokens.increment();

        // Adjust the lastPrice by +10 as per requirement
        lastPrice += increaseRate;
    }
    
    // @zherring NATSPEC
    // Another small issue with this function is that is asks for the epoch number and nftId which are emitted in separate events.
    // So the user and/or the dev team will need to listen for and aggregate this data. Alternately you could emit this data in the billboard change event so it is in one place. 
    // @captnseagraves -- unsure what this would look like. On set billboard it would emit an event with the epoch number and max qualified NFT id? 
    /**
     * @dev Allows an NFT owner to claim their share of the revenue generated from the billboard advertisement for a specific epoch.
     * This function checks that the caller is the owner of the NFT, the epoch number is valid, and the share for the given epoch has not already been claimed.
     * It then calculates the amount owed based on the revenue generated during the specified epoch and transfers this amount to the NFT owner.
     *
     * Requirements:
     * - The caller must be the owner of the NFT.
     * - The epoch number must be valid and not exceed the current epoch.
     * - The share for the specified epoch and NFT ID must not have already been claimed.
     * - The NFT ID must be eligible for the specified epoch (i.e., it was minted before the epoch ended).
     * - The contract must have a sufficient balance to cover the withdrawal.
     *
     * Emits a `WithdrawalSuccessful` event upon a successful withdrawal.
     *
     * @param epochNumber The epoch number for which the share is being claimed.
     * @param nftId The ID of the NFT for which the share is being claimed.
     */
	function claimShare(uint256 epochNumber, uint256 nftId) public {
		   
        require(ownerOf(nftId) == msg.sender, "Caller does not own the NFT"); // Verify the caller owns the NFT
        require(epochNumber <= currentEpoch, "Invalid epoch number"); // Ensure the epochNumber is valid
        require(!hasWithdrawn[epochNumber][nftId], "Already withdrawn");

        // Get the epoch data
        epochData storage data = epochs[epochNumber];

        // Ensure the NFT ID is within the range for the epoch
        require(nftId <= data.nftsMinted, "NFT ID is not eligible for this epoch");

        uint256 amountOwed = data.amtOwed; // Calculate the amount owed
            require(address(this).balance >= amountOwed, "Insufficient contract balance");

        // Mark as withdrawn
        hasWithdrawn[epochNumber][nftId] = true;

        // Transfer the amount owed to the caller
            Address.sendValue(payable(msg.sender), amountOwed);

        // Emitting successful withdrawal
            emit WithdrawalSuccessful(epochNumber, nftId, amountOwed);                  
	}
    /**
     * @dev Allows an NFT owner to claim their share of the revenue generated from the billboard advertisement across all epochs in which they have not yet claimed their share.
     * This function iterates through all epochs, checks if the NFT owner has already claimed their share for each epoch, and if not, calculates and accumulates the amount owed to them.
     * Once the total share is calculated, it transfers the accumulated amount to the NFT owner in a single transaction.
     * This function ensures that NFT owners can conveniently claim their revenue share from multiple epochs in one transaction, reducing transaction costs and complexity.
     *
     * Requirements:
     * - The caller must be the owner of the NFT.
     * - The NFT must be eligible for revenue share in the epochs being claimed (i.e., it was minted before the epoch ended).
     * - The contract must have a sufficient balance to cover the total share being claimed.
     * - The NFT must not have already withdrawn the amount!
     *
     * Emits a `WithdrawalSuccessful` event for each epoch from which a share is successfully claimed.
     *
     * @param nftId The ID of the NFT for which the share is being claimed across all eligible epochs.
     */
	function claimShareAll(uint256 nftId) public {
        require(ownerOf(nftId) == msg.sender, "Caller does not own the NFT");

        uint256 totalShare = 0;

        for (uint256 epochNumber = 1; epochNumber <= currentEpoch; epochNumber++) {
            if (!hasWithdrawn[epochNumber][nftId] && nftId <= epochs[epochNumber].nftsMinted) {
                epochData storage data = epochs[epochNumber];

                uint256 amountOwed = data.amtOwed;
                require(address(this).balance >= amountOwed, "Insufficient contract balance");

                // Mark as withdrawn
                hasWithdrawn[epochNumber][nftId] = true;

                // Accumulate the amount owed
                totalShare += amountOwed;

                // Emitting successful withdrawal for each epoch
                emit WithdrawalSuccessful(epochNumber, nftId, amountOwed);
            }
        }

        // After calculating the total amount owed across all epochs, transfer it in a single transaction
        if (totalShare > 0) {
            Address.sendValue(payable(msg.sender), totalShare);
        }
    }
    // Allows contract owner to set new URI for NFTs
	function setCommonURI(string memory newURI) public onlyOwner {
			_commonURI = newURI;
	}

     /**
     * @dev Withdraws the accumulated protocol fees to the contract owner's address.
     * This function can only be called by the contract owner. It transfers the total accumulated
     * protocol fees to the owner and resets the protocol revenue to zero.
     * 
     * Emits a `Transfer` event if the transfer is successful.
     *
     * Requirements:
     * - Can only be called by the contract owner.
     *
     * @notice Use this function to withdraw the accumulated protocol fees to the owner's address.
     */
    function withdrawProtocolFees() public onlyOwner {
        uint256 amount = protocolRevenue;
        protocolRevenue = 0; // Reset the accumulated fees to 0

        // Transfer the accumulated fees to the owner
        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "Transfer failed.");
    }

    /**
     * @dev Function to allow the owner to change the billboard message. Message is optional, otherwise it defaults to start message. In case of spam or harmful messages!
     * @param _newBillboardMessage The new message to set on the billboard.
     * @param _newBillboardURL The new URL to set on the billboard.
     */
		function adminSetBillboardMessage(string memory _newBillboardMessage, string memory _newBillboardURL) public onlyOwner {
				if (bytes(_newBillboardMessage).length == 0) {
						billboard = "This Space for Sale"; // Default message
				} else {
						billboard = _newBillboardMessage;
				}

				if (bytes(_newBillboardURL).length == 0) {
						billboardURL = "https://adframe.xyz"; // Default URL
				} else {
						billboardURL = _newBillboardURL;
				}

				// Optionally, you can emit an event when the billboard message is changed by the admin
				emit BillboardChange(msg.sender, billboard, billboardURL, 0);
		}

		function adminSetProtocolFee(uint256 _newFeePercent) public onlyOwner {
        require(_newFeePercent <= 100, "Fee cannot exceed 100%");
        protocolFee = _newFeePercent;
    }

    /**
     * @dev Allows the admin to set a new base price (e.g, lowest possible price to charge for the adspace)
     * @param _newBasePrice The new base price to be set.
     */
    function setBasePrice(uint256 _newBasePrice) public onlyOwner {
        basePrice = _newBasePrice;
    }

    /**
     * @dev Allows the admin to set a new decrease rate. Decrease rate is applied every block to AdjustedPrice.
     * @param _newDecreaseRate The new decrease rate to be set.
     */
    function setDecreaseRate(uint256 _newDecreaseRate) public onlyOwner {
        decreaseRate = _newDecreaseRate;
    }

    /**
     * @dev Allows the admin to set a new increase rate. Increase rate is applied upon updateBillboard and mintNFT
     * @param _newIncreaseRate The new increase rate to be set.
     */
    function setIncreaseRate(uint256 _newIncreaseRate) public onlyOwner {
        increaseRate = _newIncreaseRate;
    }

    // Override the _transfer function to prevent transfers
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        revert("NFTs are non-transferable");
    }

    /**
     * @dev allows user to burn the billboard. Adjusts the activeTokens count so accurate shares are recorded for future epochs.
     * @param tokenId is token to be burned
     */
		function burn(uint256 tokenId) public {
			require(ownerOf(tokenId) == msg.sender, "Caller is not the token owner");
			_burn(tokenId);
			_activeTokens.decrement();
		}

    function totalActiveTokens() public view returns (uint256) {
        return _activeTokens.current();
    }
    /**
     * @dev If the contract receives ETH, the ETH is split between all NFT owners without resetting the billboard message or the adjusted fee.
     * could be a fun way to reward ALL NFT holders!
     */
    receive() external payable {
        // Ensure some ETH is sent
        require(msg.value > 0, "No ETH sent");

        // Ensure there are NFTs minted before proceeding
        uint256 nftsMintedSoFar = _activeTokens.current();
        require(nftsMintedSoFar > 0, "No NFTs minted");

        // Calculate the protocol fee and the remainder to be distributed
        uint256 fee = msg.value * protocolFee / 100;
        protocolRevenue += fee;
        uint256 remainder = msg.value - fee;

        // Create a new epoch entry
        currentEpoch += 1; // Move to next epoch

        // Calculate the amount owed per NFT
        uint256 amtOwedPerNFT = remainder / nftsMintedSoFar;

        // Store the new epoch data
        uint256 totalNFTsMinted = _tokenIds.current();
        epochs[currentEpoch] = epochData(totalNFTsMinted, amtOwedPerNFT);

        // Emit an event for the new epoch creation
        emit EpochUpdated(currentEpoch, totalNFTsMinted, amtOwedPerNFT);
	}
}

