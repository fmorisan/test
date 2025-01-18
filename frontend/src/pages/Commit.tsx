import { PageHeader, PageHeaderHeading } from "@/components/page-header";
import RevealForm from "@/components/reveal-form";
import SecretForm, { FragmentData, PrefilledMessageParams } from "@/components/secret-form";
import { Card, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { useLocation } from 'react-router-dom'

export default function Commit() {
    const location = useLocation()
    let fragmentData: FragmentData | null = null

    if (location.hash) {
        fragmentData = JSON.parse(Buffer.from(location.hash.slice(1), 'base64').toString('binary'))
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
                <SecretForm data={fragmentData} />
            </Card>
        </>
    )
}
