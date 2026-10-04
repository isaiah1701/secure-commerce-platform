const API_ROOT = import.meta.env.VITE_API_URL || ''

export class ApiError extends Error {
  status: number
  requestId?: string
  constructor(message: string, status: number, requestId?: string) {
    super(message)
    this.status = status
    this.requestId = requestId
  }
}

export async function api<T>(path: string, options: RequestInit = {}): Promise<T> {
  const token = localStorage.getItem('commerce_token')
  const headers = new Headers(options.headers)
  if (options.body) headers.set('Content-Type', 'application/json')
  if (token) headers.set('Authorization', `Bearer ${token}`)
  headers.set('X-Request-ID', crypto.randomUUID())

  const response = await fetch(`${API_ROOT}${path}`, { ...options, headers })
  if (!response.ok) {
    let body: { detail?: string; error?: string; request_id?: string } = {}
    try { body = await response.json() } catch { /* response is not JSON */ }
    throw new ApiError(body.detail || body.error || 'Something went wrong', response.status, body.request_id || response.headers.get('X-Request-ID') || undefined)
  }
  if (response.status === 204) return undefined as T
  return response.json() as Promise<T>
}
