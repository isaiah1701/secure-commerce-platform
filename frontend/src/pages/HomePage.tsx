import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { api } from '../api/client'
import { ProductCard } from '../components/ProductCard'
import type { Product } from '../types'

export function HomePage() {
  const [products, setProducts] = useState<Product[]>([])
  useEffect(() => { api<Product[]>('/api/products').then(data => setProducts(data.slice(0, 4))).catch(() => {}) }, [])
  return <>
    <section className="hero">
      <div className="hero-copy"><span className="hero-pill">Secure shopping, minus the fuss</span><h1>Good stuff.<br/><em>Safe shopping.</em></h1><p>A small, friendly store with serious security underneath. Browse brilliant everyday products and check out with confidence.</p><div className="hero-actions"><Link to="/products" className="button">Start shopping <span>→</span></Link><a href="#principles" className="text-link">See how we protect you</a></div><div className="trust-row"><span>✓ Argon2 passwords</span><span>✓ Private orders</span><span>✓ No real card data</span></div></div>
      <div className="hero-visual" aria-label="Secure shopping illustration"><div className="orbit orbit-one"></div><div className="orbit orbit-two"></div><div className="shopping-card"><div className="card-top"><span className="mini-brand">S</span><span>SECURE COMMERCE</span></div><div className="card-product"><div className="product-blob">⌁</div><div><small>ORDER PROTECTED</small><b>Ready when you are</b></div></div><div className="card-status"><span className="pulse"></span>Everything looks good</div></div><div className="security-bubble"><span>✓</span><b>Safe by default</b><small>Your account, cart and orders stay yours.</small></div></div>
    </section>
    <section className="category-strip"><span>Browse by collection</span>{['Electronics','Clothing','Home','Accessories'].map((category, i) => <Link key={category} to={`/products?category=${category}`}><small>0{i+1}</small>{category}<b>→</b></Link>)}</section>
    <section className="section featured"><div className="section-heading"><div><p className="eyebrow">The edit</p><h2>Selected for you</h2></div><Link to="/products" className="text-link">View all products →</Link></div><div className="product-grid">{products.map(product => <ProductCard product={product} key={product.id}/>)}</div></section>
    <section className="principles" id="principles"><div><p className="eyebrow">Our principles</p><h2>Trust, built into<br/>every interaction.</h2></div><div className="principle-grid"><article><span>01</span><h3>Protected by design</h3><p>Modern password security, account safeguards, and strict access controls work quietly behind every visit.</p></article><article><span>02</span><h3>Clear by default</h3><p>No hidden charges and no real payment details collected in this learning environment.</p></article><article><span>03</span><h3>Ready when you are</h3><p>A resilient, observable service designed to make activity understandable and issues actionable.</p></article></div></section>
  </>
}
