import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { api } from '../api/client'
import type { Cart } from '../types'

export function CartPage() {
  const [cart, setCart] = useState<Cart | null>(null); const [error, setError] = useState('')
  const load = () => api<Cart>('/api/cart').then(setCart).catch(err => setError(err.message))
  useEffect(() => { void load() }, [])
  const update = async (id: number, quantity: number) => { try { setCart(await api<Cart>(`/api/cart/items/${id}`, { method: 'PUT', body: JSON.stringify({ quantity }) })) } catch (err) { setError(err instanceof Error ? err.message : 'Unable to update bag') } }
  const remove = async (id: number) => { try { setCart(await api<Cart>(`/api/cart/items/${id}`, { method: 'DELETE' })) } catch (err) { setError(err instanceof Error ? err.message : 'Unable to remove item') } }
  if (!cart && !error) return <div className="page-state">Loading your bag…</div>
  return <div className="section page"><p className="eyebrow">Your selection</p><h1>Shopping bag</h1>{error && <div className="alert error">{error}</div>}{!cart?.items.length ? <div className="empty"><h2>Your bag is empty</h2><p>Explore practical pieces selected to last.</p><Link className="button" to="/products">Browse the collection</Link></div> : <div className="cart-layout"><div className="cart-list">{cart.items.map(item => <article className="cart-item" key={item.id}>{item.product.image_url && <img src={item.product.image_url} alt=""/>}<div><p className="eyebrow">{item.product.category}</p><Link to={`/products/${item.product_id}`}><h3>{item.product.name}</h3></Link><button className="link-button danger" onClick={() => remove(item.id)}>Remove</button></div><label>Qty<select value={item.quantity} onChange={e => update(item.id, Number(e.target.value))}>{Array.from({ length: Math.min(item.product.stock_quantity, 10) }, (_, i) => <option key={i+1}>{i+1}</option>)}</select></label><strong>£{Number(item.line_total).toFixed(2)}</strong></article>)}</div><aside className="summary"><h2>Order summary</h2><p><span>Subtotal</span><span>£{Number(cart.total).toFixed(2)}</span></p><p><span>Delivery</span><span>{Number(cart.total) >= 75 ? 'Complimentary' : 'Not charged in demo'}</span></p><hr/><p className="summary-total"><span>Simulated total</span><b>£{Number(cart.total).toFixed(2)}</b></p><small>Checkout is simulated. No payment information will be requested.</small><Link to="/checkout" className="button full">Continue to checkout</Link></aside></div>}</div>
}
