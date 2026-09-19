import { api } from './client'

export interface AuthResponse {
  token: string
  username: string
}

export async function login(username: string, password: string): Promise<AuthResponse> {
  const res = await api.post<AuthResponse>('/auth/login', { username, password })
  return res.data
}

export async function register(username: string, email: string, password: string): Promise<AuthResponse> {
  const res = await api.post<AuthResponse>('/auth/register', { username, email, password })
  return res.data
}
