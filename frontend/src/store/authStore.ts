import { create } from 'zustand'

interface AuthState {
  token: string | null
  username: string | null
  setAuth: (token: string, username: string) => void
  logout: () => void
}

const storedToken = sessionStorage.getItem('ec2mgr_token')
const storedUser = sessionStorage.getItem('ec2mgr_username')

export const useAuthStore = create<AuthState>((set) => ({
  token: storedToken,
  username: storedUser,
  setAuth: (token, username) => {
    sessionStorage.setItem('ec2mgr_token', token)
    sessionStorage.setItem('ec2mgr_username', username)
    set({ token, username })
  },
  logout: () => {
    sessionStorage.removeItem('ec2mgr_token')
    sessionStorage.removeItem('ec2mgr_username')
    set({ token: null, username: null })
  },
}))
