import React, { useState, useEffect } from 'react';
import { Address, EtherInput, InputBase } from "~~/components/scaffold-eth";
import { useScaffoldContract, useScaffoldContractRead, useScaffoldContractWrite } from "~~/hooks/scaffold-eth";
import { useAccount } from 'wagmi';


interface WithdrawShareProps {

}

const WithdrawShare: React.FC<WithdrawShareProps> = ({  }) => {

  const [epoch, setEpoch] = useState<string>();
  const [bString, setbString] = useState<string>();

  const { address, isConnected } = useAccount();

  // / get the token id for user 
  const { data: id, error} = useScaffoldContractRead({
    contractName: "YourContract",
    functionName: "tokenOfOwnerByIndex",
    args: [address, BigInt(0)],
  });

  // Handle cases where the address owns no tokens
if (error && error.message.includes("owner index out of bounds")) {
  console.error("The address does not own a Billboard NFT.");
  // Handle the error (e.g., disable functionality, show a message to the user)
} else if (id) {
  // Proceed with functionality for when the token ID is successfully retrieved
}


  const [tokenID, setTokenID] = useState<number | undefined>();
  const [epochID, setEpochID] = useState<number | undefined>(); 

  const { writeAsync, isLoading, isMining } = useScaffoldContractWrite ({
    contractName: "YourContract",
    functionName: "claimSharesAll",
    args: [tokenID !== undefined ? BigInt(tokenID) : undefined],
  })

    return(
      <>
        <div>
          {/* Withdraw Share for {address} & id: {id?.toString()}
          <button className="btn btn-primary" onClick={() => writeAsync()} disabled={isLoading}>
            {isLoading ? <span className="loading loading-spinner loading-sm"></span> : <>Withdraw All</>}
          </button> */}
        </div>
      </>
    )
};

export default WithdrawShare;