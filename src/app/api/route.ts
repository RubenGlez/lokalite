export async function GET(request: Request) {
  return Response.json({
    data: {
      message: "It's works!",
      url: request.url
    }
  })
}
