import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import { api } from '../api/client'
import type { User } from '../types'

interface AuthValue {
  user: User | null
  loading: boolean
  login: (email: string, password: string) => Promise<void>
  register: (data: RegisterData) => Promise<void>
  logout: () => void
}

interface RegisterData { email: string; password: string; first_name: string; last_name: string }
interface AuthResponse { access_token: string; user: User }

const AuthContext = createContext<AuthValue | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [loading, setLoading] = useState(() => Boolean(localStorage.getItem('commerce_token')))

  useEffect(() => {
    if (!localStorage.getItem('commerce_token')) return
    api<User>('/api/auth/me').then(setUser).catch(() => localStorage.removeItem('commerce_token')).finally(() => setLoading(false))
  }, [])

  const applyAuth = (result: AuthResponse) => {
    localStorage.setItem('commerce_token', result.access_token)
    setUser(result.user)
  }

  const login = async (email: string, password: string) => applyAuth(await api<AuthResponse>('/api/auth/login', { method: 'POST', body: JSON.stringify({ email, password }) }))
  const register = async (data: RegisterData) => applyAuth(await api<AuthResponse>('/api/auth/register', { method: 'POST', body: JSON.stringify(data) }))
  const logout = () => {
    void api('/api/auth/logout', { method: 'POST' }).catch(() => undefined)
    localStorage.removeItem('commerce_token')
    setUser(null)
  }

  return <AuthContext.Provider value={{ user, loading, login, register, logout }}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const value = useContext(AuthContext)
  if (!value) throw new Error('useAuth must be used inside AuthProvider')
  return value
}
