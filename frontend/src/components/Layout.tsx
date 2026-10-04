import { Link, NavLink, Outlet } from 'react-router-dom'
import { useAuth } from '../auth/AuthContext'

export function Layout() {
  const { user, logout } = useAuth()
  return <>
    <div className="notice"><span className="live-dot"></span> Secure Commerce is healthy <span>•</span> Free delivery over £75</div>
    <header className="site-header">
      <Link to="/" className="brand"><span className="brand-mark">S</span><span>SECURE<br/><b>COMMERCE</b></span></Link>
      <nav>
        <NavLink to="/products">Shop all</NavLink>
        {user && <NavLink to="/orders">Orders</NavLink>}
        {user?.role === 'admin' && <NavLink to="/admin">Admin</NavLink>}
      </nav>
      <div className="header-actions">
        {user ? <>
          <span className="welcome">Hello, {user.first_name}</span>
          <Link to="/cart" className="icon-link" aria-label="Shopping cart">Bag</Link>
          <button className="link-button" onClick={logout}>Sign out</button>
        </> : <>
          <Link to="/login">Sign in</Link>
          <Link to="/register" className="button small">Create account</Link>
        </>}
      </div>
    </header>
    <main><Outlet /></main>
    <footer>
      <div><Link to="/" className="footer-brand">SECURE COMMERCE</Link><p>Considered essentials for modern life.<br/>Protected from browse to basket.</p></div>
      <div><b>Shop</b><Link to="/products">All products</Link><Link to="/products?category=Electronics">Electronics</Link><Link to="/products?category=Home">Home</Link></div>
      <div><b>Trust</b><span>Secure payments</span><span>Privacy by design</span><a href="/health">System health</a></div>
      <small>© 2026 Secure Commerce. Learning environment — no real payments are collected.</small>
    </footer>
  </>
}
