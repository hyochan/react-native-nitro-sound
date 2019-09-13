const ROOT_URL = 'http://localhost:3000/api';

export const sample = async (
  body: object
  // signal?: AbortController['signal']
) => {
  try {
    let res: any = await fetch(`${ROOT_URL}/sample`, {
      // signal,
      method: 'POST',
      headers: new Headers({
        Accept: 'application/json',
        'Content-Type': 'application/json',
      }),
      body: JSON.stringify(body),
    });

    if (res) {
      res = JSON.parse(res._bodyInit);
      return res;
    }
    return null;
  } catch (err) {
    throw new Error(err);
  }
};
