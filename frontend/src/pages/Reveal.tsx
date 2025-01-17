import { PageHeader, PageHeaderHeading } from "@/components/page-header";
import RevealForm from "@/components/reveal-form";
import SecretForm from "@/components/secret-form";
import { Card, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { useLocation, useParams } from 'react-router-dom'

export default function Reveal() {
    const location = useLocation()
    const { id } = useParams()
    return (
        <>
            <PageHeader>
                <PageHeaderHeading>Dashboard</PageHeaderHeading>
            </PageHeader>
            <Card>
                <CardHeader>
                    <CardTitle>Reveal a secret</CardTitle>
                </CardHeader>
                <RevealForm secretId={BigInt(id!).valueOf()} />
            </Card>
        </>
    )
}
