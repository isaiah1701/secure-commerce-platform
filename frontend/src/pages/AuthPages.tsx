import { useState, type FormEvent } from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { useAuth } from '../auth/AuthContext'

export function LoginPage() {
  const { login } = useAuth(); const navigate = useNavigate(); const location = useLocation()
  const [email, setEmail] = useState(''); const [password, setPassword] = useState(''); const [error, setError] = useState(''); const [busy, setBusy] = useState(false)
  const submit = async (event: FormEvent) => { event.preventDefault(); setBusy(true); setError(''); try { await login(email, password); navigate(location.state?.from?.pathname || '/') } catch (err) { setError(err instanceof Error ? err.message : 'Unable to sign in') } finally { setBusy(false) } }
  return <AuthShell title="Welcome back" intro="Sign in to view your bag, orders, and account."><form onSubmit={submit}><label>Email address<input type="email" value={email} onChange={e => setEmail(e.target.value)} required autoComplete="email"/></label><label>Password<input type="password" value={password} onChange={e => setPassword(e.target.value)} required autoComplete="current-password"/></label>{error && <div className="alert error">{error}</div>}<button className="button full" disabled={busy}>{busy ? 'Signing in…' : 'Sign in securely'}</button><p className="form-foot">New here? <Link to="/register">Create an account</Link></p><div className="demo-note"><b>Local demo</b><br/>customer@example.com · DemoPass!2026<br/>admin@example.com · AdminPass!2026</div></form></AuthShell>
}

export function RegisterPage() {
  const { register } = useAuth(); const navigate = useNavigate()
  const [form, setForm] = useState({ first_name: '', last_name: '', email: '', password: '' }); const [error, setError] = useState(''); const [busy, setBusy] = useState(false)
  const submit = async (event: FormEvent) => { event.preventDefault(); setBusy(true); setError(''); try { await register(form); navigate('/') } catch (err) { setError(err instanceof Error ? err.message : 'Unable to register') } finally { setBusy(false) } }
  return <AuthShell title="Create your account" intro="A secure place for your bag and order history."><form onSubmit={submit}><div className="form-row"><label>First name<input value={form.first_name} onChange={e => setForm({...form, first_name: e.target.value})} required/></label><label>Last name<input value={form.last_name} onChange={e => setForm({...form, last_name: e.target.value})} required/></label></div><label>Email address<input type="email" value={form.email} onChange={e => setForm({...form, email: e.target.value})} required/></label><label>Password<input type="password" minLength={10} value={form.password} onChange={e => setForm({...form, password: e.target.value})} required/><small>10+ characters with uppercase, lowercase, a number, and a symbol.</small></label>{error && <div className="alert error">{error}</div>}<button className="button full" disabled={busy}>{busy ? 'Creating account…' : 'Create secure account'}</button><p className="form-foot">Already have an account? <Link to="/login">Sign in</Link></p></form></AuthShell>
}

function AuthShell({ title, intro, children }: { title: string; intro: string; children: React.ReactNode }) {
  return <div className="auth-page"><div className="auth-image"><div><p className="eyebrow">Secure by design</p><blockquote>“Good commerce begins with trust.”</blockquote></div></div><div className="auth-panel"><div className="auth-box"><Link to="/" className="brand"><span className="brand-mark">S</span><span>SECURE<br/><b>COMMERCE</b></span></Link><h1>{title}</h1><p>{intro}</p>{children}</div></div></div>
}
