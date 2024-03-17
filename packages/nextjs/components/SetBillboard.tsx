import React, { useState, useEffect } from 'react';
import { Address, EtherInput, InputBase } from "~~/components/scaffold-eth";
import { useScaffoldContract, useScaffoldContractWrite } from "~~/hooks/scaffold-eth";
import { ethers } from 'ethers'; // Import ethers for utility functions


interface SetBillboardProps {
  ethAmount: string;
}


const SetBillboard: React.FC<SetBillboardProps> = ({ ethAmount }) => {

    const [bString, setbString] = useState<string>();
    const [sendAmount, setSendAmount] = useState<string>(ethAmount);
    
    // Update sendAmount if ethAmount changes
    useEffect(() => {
      setSendAmount(ethAmount);
    }, [ethAmount]);
    
    const { writeAsync, isLoading, isMining } = useScaffoldContractWrite ({
      contractName: "YourContract",
      functionName: "setBillboard",
      args: [bString],
      value: BigInt(sendAmount),
    })

    return(
      <>
        <div>
          what is the send amount? {sendAmount}
          <EtherInput value={sendAmount} onChange={amount => setSendAmount(amount)}></EtherInput>
          <InputBase 
            name="newBillboardString" 
            placeholder="Your New Message" 
            value={bString} 
            onChange={setbString} />
          <button className="btn btn-primary" onClick={() => writeAsync()} disabled={isLoading}>
            {isLoading ? <span className="loading loading-spinner loading-sm"></span> : <>Send</>}
          </button>
        </div>
      </>
    )
};

export default SetBillboard;