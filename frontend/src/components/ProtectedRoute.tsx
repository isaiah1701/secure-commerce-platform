import type { ReactNode } from 'react'
import { Navigate, useLocation } from 'react-router-dom'
import { useAuth } from '../auth/AuthContext'

export function ProtectedRoute({ children, admin = false }: { children: ReactNode; admin?: boolean }) {
  const { user, loading } = useAuth()
  const location = useLocation()
  if (loading) return <div className="page-state">Loading your account…</div>
  if (!user) return <Navigate to="/login" state={{ from: location }} replace />
  if (admin && user.role !== 'admin') return <Navigate to="/" replace />
  return children
}
