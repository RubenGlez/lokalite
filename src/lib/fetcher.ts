async function get<Output>(url: string): Promise<Output> {
  const response = await fetch(url, {
    method: "GET",
    headers: {
      "Content-Type": "application/json",
    },
  });

  if (!response.ok) {
    const res = await response.json();
    throw res.error;
  }

  const data = await response.json();
  return data;
}

async function update<Input, Output>(
  url: string,
  body: Input
): Promise<Output> {
  const response = await fetch(url, {
    method: "PUT",
    body: JSON.stringify(body),
    headers: {
      "Content-Type": "application/json",
    },
  });

  if (!response.ok) {
    const res = await response.json();
    throw res.error;
  }

  const data = await response.json();
  return data;
}

export const fetcher = {
  get,
  update,
};
