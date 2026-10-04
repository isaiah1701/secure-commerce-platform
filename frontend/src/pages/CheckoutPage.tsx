import { useEffect, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { api } from '../api/client'
import type { Cart, Order } from '../types'

export function CheckoutPage() {
  const [cart, setCart] = useState<Cart | null>(null); const [error, setError] = useState(''); const [busy, setBusy] = useState(false); const navigate = useNavigate()
  useEffect(() => { api<Cart>('/api/cart').then(setCart).catch(err => setError(err.message)) }, [])
  const placeOrder = async () => { setBusy(true); setError(''); try { const order = await api<Order>('/api/orders', { method: 'POST' }); navigate(`/orders/${order.id}/confirmed`, { state: { order } }) } catch (err) { setError(err instanceof Error ? err.message : 'Checkout failed') } finally { setBusy(false) } }
  return <div className="section checkout-page"><Link to="/cart" className="back-link">← Return to bag</Link><div className="checkout-grid"><div><p className="eyebrow">Final step</p><h1>Review and confirm</h1><div className="simulation"><span>✓</span><div><b>Safe checkout simulation</b><p>This training store never asks for or processes card information. Confirming will create your order and adjust stock only.</p></div></div><h3>What happens next</h3><ol className="steps"><li><span>1</span>Stock is checked and reserved</li><li><span>2</span>Your order snapshot is created</li><li><span>3</span>A confirmation appears in your history</li></ol>{error && <div className="alert error">{error}</div>}</div><aside className="summary"><h2>Your order</h2>{cart?.items.map(item => <p key={item.id}><span>{item.quantity} × {item.product.name}</span><span>£{Number(item.line_total).toFixed(2)}</span></p>)}<hr/><p className="summary-total"><span>Simulated total</span><b>£{Number(cart?.total || 0).toFixed(2)}</b></p><button className="button full" onClick={placeOrder} disabled={busy || !cart?.items.length}>{busy ? 'Confirming…' : 'Confirm order'}</button><small>By confirming, you acknowledge this is a demonstration transaction.</small></aside></div></div>
}
