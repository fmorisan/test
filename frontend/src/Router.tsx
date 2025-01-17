import { createBrowserRouter, Navigate } from "react-router-dom";

import { Applayout } from "./components/layouts/AppLayout";

import Commit from "./pages/Commit";
import Reveal from "./pages/Reveal";
import RevealSelect from "./pages/RevealSelect";

export const router = createBrowserRouter([
    {
        path: "/",
        element: <Applayout />,
        children: [
            {
                path: "commit",
                element: <Commit />,
            },
            {
                path: "reveal/:id",
                element: <Reveal />,
            },
            {
                path: "reveal",
                element: <RevealSelect />,
            },
            {
                path: "*",
                element: <Navigate to="commit" replace />,
            }
        ],
    },
    {
        path: "*",
        element: <Navigate to="commit" replace />,
    },
], {
    basename: global.basename
})
