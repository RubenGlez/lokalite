import ArgumentParser
import LokaliteCore

struct SeedCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "seed",
        abstract: "Wipe the vault and populate it with sample data for testing.",
        shouldDisplay: false
    )

    func run() throws {
        guard VaultConfiguration.isDevelopmentBuild else {
            print("Seed is only available in development builds. Production vaults are never seeded.")
            throw ExitCode.failure
        }

        try withVault { vault in
            print("Clearing existing data…")
            let cleared = try wipe(vault)
            print("Cleared \(cleared) project(s).")

            print("Seeding…")
            let frontend = try seedFrontend(vault)
            let api      = try seedAPI(vault)
            let mobile   = try seedMobile(vault)
            let pipeline = try seedPipeline(vault)
            _ = (frontend, mobile, pipeline)
            try vault.setActiveProject(id: api.id)

            print("""
            Done.
              Frontend App  – 2 environments, 8 secrets
              Backend API   – 3 environments, 13 secrets  ← active
              Mobile App    – 2 environments, 10 secrets
              Data Pipeline – 1 environment,  10 secrets
            Restart the app (or refresh) to see the data.
            """)
        }
    }

    // MARK: - Wipe

    private func wipe(_ vault: Vault) throws -> Int {
        let projects = try vault.listProjects()
        for project in projects {
            for info in try vault.listInfo(projectId: project.id) {
                try vault.delete(name: info.name, projectId: project.id)
            }
            for env in try vault.listEnvironments(projectId: project.id) {
                try vault.deleteEnvironment(name: env.name, projectId: env.projectId)
            }
            try vault.deleteProject(id: project.id)
        }
        return projects.count
    }

    // MARK: - Helpers

    @discardableResult
    private func secret(
        _ vault: Vault,
        _ name: String,
        _ value: String,
        desc: String? = nil,
        cat: SecretCategory? = nil,
        project: String,
        env: String? = nil
    ) throws -> Secret {
        try vault.add(name: name, value: value, description: desc,
                      category: cat, projectId: project, environmentName: env)
    }

    private func removeDefaultEnvironment(_ vault: Vault, project: Project) throws {
        try vault.deleteEnvironmentIncludingContents(name: "Default", projectId: project.id)
    }

    // MARK: - Projects

    private func seedFrontend(_ vault: Vault) throws -> Project {
        let p = try vault.addProject(name: "Frontend App", icon: "safari")
        _ = try vault.addEnvironment(name: "staging",    projectId: p.id, color: "#6DAFF1")
        _ = try vault.addEnvironment(name: "production", projectId: p.id, color: "#FF7B72")

        // Shared defaults
        try secret(vault, "NEXT_PUBLIC_APP_NAME",   "Lokalite",
                   desc: "App display name", project: p.id, env: "staging")
        try secret(vault, "NEXT_PUBLIC_APP_NAME",   "Lokalite",
                   desc: "App display name", project: p.id, env: "production")
        try secret(vault, "NEXT_PUBLIC_SENTRY_DSN", "https://a1b2c3@o123456.ingest.sentry.io/456789",
                   desc: "Error tracking DSN", project: p.id, env: "staging")
        try secret(vault, "NEXT_PUBLIC_SENTRY_DSN", "https://a1b2c3@o123456.ingest.sentry.io/456789",
                   desc: "Error tracking DSN", project: p.id, env: "production")

        // Per-environment
        let envs: [(name: String, apiUrl: String, stripe: String, ga: String)] = [
            ("staging",
             "https://api-staging.example.com",
             "pk_test_replace_me_with_your_stripe_publishable_key",
             "G-STAGING1234"),
            ("production",
             "https://api.example.com",
             "pk_live_replace_me_with_your_stripe_publishable_key",
             "G-PROD567890"),
        ]
        for e in envs {
            try secret(vault, "NEXT_PUBLIC_API_URL",      e.apiUrl,  project: p.id, env: e.name)
            try secret(vault, "NEXT_PUBLIC_STRIPE_PK",    e.stripe,  cat: .apiKey, project: p.id, env: e.name)
            try secret(vault, "NEXT_PUBLIC_ANALYTICS_ID", e.ga,      project: p.id, env: e.name)
        }
        try removeDefaultEnvironment(vault, project: p)
        return p
    }

    private func seedAPI(_ vault: Vault) throws -> Project {
        let p = try vault.addProject(name: "Backend API", icon: "server.rack")
        _ = try vault.addEnvironment(name: "staging",    projectId: p.id, color: "#62D2C3")
        _ = try vault.addEnvironment(name: "production", projectId: p.id, color: "#FF7B72")
        _ = try vault.addEnvironment(name: "testing",    projectId: p.id, color: "#F2CC60")

        // Shared defaults
        try secret(vault, "JWT_SECRET",
                   "dev-jwt-secret-please-change-in-production-a1b2c3d4e5f6g7h8",
                   desc: "HS256 signing secret", cat: .token, project: p.id, env: "testing")
        try secret(vault, "JWT_REFRESH_SECRET",
                   "dev-refresh-secret-please-change-in-production-z9y8x7w6v5u4t3s2",
                   cat: .token, project: p.id, env: "testing")
        try secret(vault, "OPENAI_API_KEY",
                   "sk-proj-fakeOpenAIKeyForLocalTestingDoNotUseInProduction1234567890",
                   cat: .apiKey, project: p.id, env: "testing")
        try secret(vault, "SENDGRID_API_KEY",
                   "SG.fakeApiKeyForTestingXXXXXXXXXXXX.XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
                   cat: .apiKey, project: p.id, env: "testing")
        try secret(vault, "STRIPE_WEBHOOK_SECRET",
                   "whsec_test_fakeWebhookSecretForLocalDevXXXXXXXXXXXXXXXXXXXX",
                   project: p.id, env: "testing")

        // DATABASE_URL across three environments
        let dbUrls: [(env: String, url: String)] = [
            ("staging",    "postgresql://api:s3cr3t@staging-db.example.com:5432/apidb"),
            ("production", "postgresql://api:s3cr3t@prod-db.example.com:5432/apidb"),
            ("testing",    "postgresql://localhost:5432/apidb_test"),
        ]
        for e in dbUrls {
            try secret(vault, "DATABASE_URL", e.url, cat: .database, project: p.id, env: e.env)
        }

        // REDIS_URL across three environments
        let redisUrls: [(env: String, url: String)] = [
            ("staging",    "redis://:r3dis@staging-redis.example.com:6379/0"),
            ("production", "redis://:r3dis@prod-redis.example.com:6379/0"),
            ("testing",    "redis://localhost:6379/1"),
        ]
        for e in redisUrls {
            try secret(vault, "REDIS_URL", e.url, cat: .database, project: p.id, env: e.env)
        }

        // Stripe (staging + production only)
        try secret(vault, "STRIPE_SECRET_KEY",
                   "sk_test_replace_me_with_your_stripe_secret_key",
                   cat: .apiKey, project: p.id, env: "staging")
        try secret(vault, "STRIPE_SECRET_KEY",
                   "sk_live_replace_me_with_your_stripe_secret_key",
                   cat: .apiKey, project: p.id, env: "production")

        // App URL
        try secret(vault, "APP_URL", "https://staging.example.com", project: p.id, env: "staging")
        try secret(vault, "APP_URL", "https://example.com",          project: p.id, env: "production")

        try removeDefaultEnvironment(vault, project: p)
        return p
    }

    private func seedMobile(_ vault: Vault) throws -> Project {
        let p = try vault.addProject(name: "Mobile App", icon: "iphone")
        _ = try vault.addEnvironment(name: "staging",    projectId: p.id, color: "#9B87F1")
        _ = try vault.addEnvironment(name: "production", projectId: p.id, color: "#FF7B72")

        // Shared defaults
        try secret(vault, "SENTRY_DSN",
                   "https://xyz789@o654321.ingest.sentry.io/123456",
                   desc: "Mobile crash reporting", project: p.id, env: "staging")
        try secret(vault, "SENTRY_DSN",
                   "https://xyz789@o654321.ingest.sentry.io/123456",
                   desc: "Mobile crash reporting", project: p.id, env: "production")
        try secret(vault, "GOOGLE_MAPS_API_KEY",
                   "AIzaSyFakeGoogleMapsKeyForLocalDevTesting12345",
                   cat: .apiKey, project: p.id, env: "staging")
        try secret(vault, "GOOGLE_MAPS_API_KEY",
                   "AIzaSyFakeGoogleMapsKeyForLocalDevTesting12345",
                   cat: .apiKey, project: p.id, env: "production")
        try secret(vault, "APPLE_TEAM_ID",          "ZYXWV98765", project: p.id, env: "staging")
        try secret(vault, "APPLE_TEAM_ID",          "ZYXWV98765", project: p.id, env: "production")
        try secret(vault, "APNS_KEY_ID",            "ABCDE12345", project: p.id, env: "staging")
        try secret(vault, "APNS_KEY_ID",            "ABCDE12345", project: p.id, env: "production")

        // Per-environment
        let envs: [(name: String, apiUrl: String, fbKey: String, fbProject: String)] = [
            ("staging",
             "https://api-staging.example.com/mobile/v1",
             "AIzaSyFakeFirebaseKeyStagingXXXXXXXXXXX",
             "myapp-staging"),
            ("production",
             "https://api.example.com/mobile/v1",
             "AIzaSyFakeFirebaseKeyProductionXXXXXXXX",
             "myapp-production"),
        ]
        for e in envs {
            try secret(vault, "API_BASE_URL",        e.apiUrl,     project: p.id, env: e.name)
            try secret(vault, "FIREBASE_API_KEY",    e.fbKey,      cat: .apiKey, project: p.id, env: e.name)
            try secret(vault, "FIREBASE_PROJECT_ID", e.fbProject,  project: p.id, env: e.name)
        }
        try removeDefaultEnvironment(vault, project: p)
        return p
    }

    private func seedPipeline(_ vault: Vault) throws -> Project {
        let p = try vault.addProject(name: "Data Pipeline", icon: "chart.bar.xaxis")
        _ = try vault.addEnvironment(name: "production", projectId: p.id, color: "#FF7B72")

        // Shared defaults
        try secret(vault, "DATADOG_API_KEY",
                   "ddapiXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
                   cat: .apiKey, project: p.id, env: "production")
        try secret(vault, "AWS_ACCESS_KEY_ID",     "AKIAIOSFODNN7EXAMPLE",
                   cat: .secret, project: p.id, env: "production")
        try secret(vault, "AWS_SECRET_ACCESS_KEY", "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
                   cat: .secret, project: p.id, env: "production")
        try secret(vault, "AWS_REGION",            "us-east-1", project: p.id, env: "production")
        try secret(vault, "S3_BUCKET_NAME",        "myapp-data-lake-prod", project: p.id, env: "production")

        // Production
        let prod = "production"
        try secret(vault, "POSTGRES_READ_REPLICA_URL",
                   "postgresql://readonly:s3cr3t@replica.example.com:5432/analytics",
                   cat: .database, project: p.id, env: prod)
        try secret(vault, "SNOWFLAKE_ACCOUNT",
                   "xy12345.us-east-1.aws", project: p.id, env: prod)
        try secret(vault, "SNOWFLAKE_PASSWORD",
                   "FakeSnowflakeP@ssw0rd!", cat: .password, project: p.id, env: prod)
        try secret(vault, "KAFKA_BOOTSTRAP_SERVERS",
                   "kafka1.example.com:9092,kafka2.example.com:9092",
                   project: p.id, env: prod)
        try secret(vault, "BIGQUERY_PROJECT_ID",
                   "myapp-analytics-prod", project: p.id, env: prod)

        try removeDefaultEnvironment(vault, project: p)
        return p
    }
}
