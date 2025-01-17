import { PageHeader, PageHeaderHeading } from "@/components/page-header";
import RevealForm from "@/components/reveal-form";
import SecretForm from "@/components/secret-form";
import { Card, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { useLocation } from 'react-router-dom'

export default function Commit() {
    const location = useLocation()

    let receivedData = {sig: undefined, message: undefined, salt: BigInt(0)}

    if (location.hash) {
        console.log('recv', location.hash)
        receivedData = JSON.parse(Buffer.from(location.hash.slice(1), 'base64').toString('binary'))
        receivedData.salt = BigInt(receivedData.salt)
    }
    return (
        <>
            <PageHeader>
                <PageHeaderHeading>Dashboard</PageHeaderHeading>
            </PageHeader>
            <Card>
                <CardHeader>
                    <CardTitle>Commit a secret</CardTitle>
                </CardHeader>
                <SecretForm otherSignature={receivedData.sig} salt={receivedData.salt} message={receivedData.message} />
            </Card>
        </>
    )
}
