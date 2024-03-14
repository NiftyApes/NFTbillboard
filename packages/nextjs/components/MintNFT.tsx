import React, { useState } from 'react';
import { Address, EtherInput, InputBase } from "~~/components/scaffold-eth";
import { useScaffoldContract, useScaffoldContractWrite } from "~~/hooks/scaffold-eth";


interface MintNFTProps {
  
}

const MintNFT: React.FC<MintNFTProps> = ({  }) => {
    
  const { writeAsync, isLoading, isMining } = useScaffoldContractWrite ({
    contractName: "YourContract",
    functionName: "mintNFT",
  })

    return(
      <>
        <div>
          Mint NFT
          <button className="btn btn-primary" onClick={() => writeAsync()} disabled={isLoading}>
            {isLoading ? <span className="loading loading-spinner loading-sm"></span> : <>Mint</>}
          </button>
        </div>
      </>
    )
};

export default MintNFT;
