import { useEffect, useState } from 'react'
import { Link, useLocation, useParams } from 'react-router-dom'
import { api } from '../api/client'
import type { Order } from '../types'

export function OrdersPage() {
  const [orders, setOrders] = useState<Order[]>([]); const [error, setError] = useState('')
  useEffect(() => { api<Order[]>('/api/orders').then(setOrders).catch(err => setError(err.message)) }, [])
  return <div className="section page"><p className="eyebrow">Your account</p><h1>Order history</h1>{error && <div className="alert error">{error}</div>}<div className="orders-list">{orders.map(order => <Link to={`/orders/${order.id}`} className="order-row" key={order.id}><div><small>Order</small><b>#{String(order.id).padStart(5,'0')}</b></div><div><small>Placed</small><span>{new Date(order.created_at).toLocaleDateString()}</span></div><div><small>Status</small><span className="status">{order.status}</span></div><div><small>Total</small><b>£{Number(order.total_amount).toFixed(2)}</b></div><span>→</span></Link>)}{!orders.length && !error && <div className="empty"><h2>No orders yet</h2><Link className="button" to="/products">Start shopping</Link></div>}</div></div>
}

export function OrderDetailPage() {
  const { id } = useParams(); const [order, setOrder] = useState<Order | null>(null); const [error, setError] = useState('')
  useEffect(() => { api<Order>(`/api/orders/${id}`).then(setOrder).catch(err => setError(err.message)) }, [id])
  if (error) return <div className="page-state"><h2>{error}</h2><Link to="/orders">Back to orders</Link></div>
  if (!order) return <div className="page-state">Loading order…</div>
  return <OrderView order={order}/>
}

export function OrderConfirmationPage() {
  const { id } = useParams(); const location = useLocation(); const [order, setOrder] = useState<Order | null>(location.state?.order || null)
  useEffect(() => { if (!order) api<Order>(`/api/orders/${id}`).then(setOrder) }, [id, order])
  if (!order) return <div className="page-state">Loading confirmation…</div>
  return <div className="confirmation"><span className="confirmation-mark">✓</span><p className="eyebrow">Payment simulated successfully</p><h1>Your order is confirmed.</h1><p>Order #{String(order.id).padStart(5,'0')} has been added to your history. No payment was taken.</p><div className="hero-actions"><Link className="button" to={`/orders/${order.id}`}>View order</Link><Link className="text-link" to="/products">Continue shopping →</Link></div></div>
}

function OrderView({ order }: { order: Order }) {
  return <div className="section page"><Link to="/orders" className="back-link">← All orders</Link><div className="order-heading"><div><p className="eyebrow">Order #{String(order.id).padStart(5,'0')}</p><h1>Order details</h1><p>Placed {new Date(order.created_at).toLocaleString()}</p></div><span className="status large">{order.status}</span></div><div className="order-detail-list">{order.items.map(item => <div key={item.id}><div><b>{item.product_name}</b><small>Quantity {item.quantity} · £{Number(item.unit_price).toFixed(2)} each</small></div><b>£{(Number(item.unit_price) * item.quantity).toFixed(2)}</b></div>)}<div className="order-total"><span>Total</span><strong>£{Number(order.total_amount).toFixed(2)}</strong></div></div></div>
}
