import { useEffect, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { api } from '../api/client'
import { useAuth } from '../auth/AuthContext'
import type { Cart, Product } from '../types'

export function ProductDetailPage() {
  const { id } = useParams(); const navigate = useNavigate(); const { user } = useAuth()
  const [product, setProduct] = useState<Product | null>(null); const [quantity, setQuantity] = useState(1); const [error, setError] = useState(''); const [adding, setAdding] = useState(false)
  useEffect(() => { api<Product>(`/api/products/${id}`).then(setProduct).catch(err => setError(err.message)) }, [id])
  const add = async () => {
    if (!user) { navigate('/login', { state: { from: { pathname: `/products/${id}` } } }); return }
    setAdding(true); setError('')
    try { await api<Cart>('/api/cart/items', { method: 'POST', body: JSON.stringify({ product_id: Number(id), quantity }) }); navigate('/cart') } catch (err) { setError(err instanceof Error ? err.message : 'Unable to add item') } finally { setAdding(false) }
  }
  if (error && !product) return <div className="page-state"><h2>{error}</h2><Link to="/products">Return to products</Link></div>
  if (!product) return <div className="page-state">Loading product…</div>
  return <div className="section detail-page"><Link to="/products" className="back-link">← Back to collection</Link><div className="detail-grid"><div className="detail-image">{product.image_url && <img src={product.image_url} alt={product.name}/>}</div><div className="detail-copy"><p className="eyebrow">{product.category}</p><h1>{product.name}</h1><p className="detail-price">£{Number(product.price).toFixed(2)}</p><p className="description">{product.description}</p><div className="stock"><span className={product.stock_quantity ? 'dot good' : 'dot'}></span>{product.stock_quantity ? `${product.stock_quantity} available` : 'Currently unavailable'}</div>{error && <div className="alert error">{error}</div>}<div className="purchase"><label>Quantity<select value={quantity} onChange={e => setQuantity(Number(e.target.value))}>{Array.from({ length: Math.min(product.stock_quantity, 10) }, (_, i) => <option key={i + 1}>{i + 1}</option>)}</select></label><button className="button" onClick={add} disabled={!product.stock_quantity || adding}>{adding ? 'Adding…' : 'Add to bag'}</button></div><div className="assurances"><p><b>✓ Secure account</b><br/>Protected access and private orders</p><p><b>↺ Simple returns</b><br/>Clear and straightforward</p></div></div></div></div>
}
