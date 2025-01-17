interface AppConfig {
    name: string,
    author: {
        name: string,
        url: string
    },
}

export const appConfig: AppConfig = {
    name: "Message Commit/Reveal PoC",
    author: {
        name: "fmorisan",
        url: "https://github.com/fmorisan/",
    }
}
