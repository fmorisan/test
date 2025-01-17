import { PageHeader, PageHeaderHeading } from "@/components/page-header";
import RevealForm from "@/components/reveal-form";
import SecretForm from "@/components/secret-form";
import { Card, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { CONTRACT_ABI, VERIFYING_CONTRACTS } from "@/config/contracts";
import { Link, useLocation, useParams } from 'react-router-dom'
import { parseAbi } from "viem";
import { useAccount, useChainId, useReadContract, useReadContracts } from "wagmi";

export default function RevealSelect() {
    const chainid = useChainId()
    const location = useLocation()
    const { id } = useParams()
    const { address } = useAccount()

    const { data: secretsStored } = useReadContract({
        address: VERIFYING_CONTRACTS[chainid],
        abi: parseAbi(CONTRACT_ABI),
        functionName: 'secretCount'
    })

    let secretIds = []
    for (let i = 0n; i < (secretsStored || 0n); i += 1n) {
        secretIds.push(i)
    }

    const { data: secrets } = useReadContracts({
        contracts: secretIds.map(n => ({
            address: VERIFYING_CONTRACTS[chainid],
            abi: parseAbi(CONTRACT_ABI),
            functionName: 'secrets',
            args: [n]
        }))
    }) 

    return (
        <>
            <PageHeader>
                <PageHeaderHeading>Select message to reveal.</PageHeaderHeading>
            </PageHeader>
            {secretsStored?.toString()}
            {(secrets||[]).map((secret, i) => 
                <Card>
                    <CardHeader>
                        <CardTitle>Secret #{i} - <Link to={`/reveal/${i}`}>Reveal</Link></CardTitle>
                    </CardHeader>
                </Card>
            )}
        </>
    )
}
