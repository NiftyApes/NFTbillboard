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
  const { data: id } = useScaffoldContractRead({
    contractName: "YourContract",
    functionName: "tokenOfOwnerByIndex",
    args: [address, BigInt(0)],
  });



  const [tokenID, setTokenID] = useState<number | undefined>();
  const [epochID, setEpochID] = useState<number | undefined>(); 

  const { writeAsync, isLoading, isMining } = useScaffoldContractWrite ({
    contractName: "YourContract",
    functionName: "claimAllShares",
    args: [tokenID !== undefined ? BigInt(tokenID) : undefined],
  })

    return(
      <>
        <div>
          Withdraw Share for {address} & id: {id?.toString()}
          <button className="btn btn-primary" onClick={() => writeAsync()} disabled={isLoading}>
            {isLoading ? <span className="loading loading-spinner loading-sm"></span> : <>Withdraw All</>}
          </button>
        </div>
      </>
    )
};

export default WithdrawShare;