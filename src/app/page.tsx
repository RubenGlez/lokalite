import Link from 'next/link'

export default async function Home() {
  return (
    <div>
      <h1>Home</h1>
      <p>
        Go to <Link href="/dashboard">Dashboard</Link>
      </p>
    </div>
  )
}
