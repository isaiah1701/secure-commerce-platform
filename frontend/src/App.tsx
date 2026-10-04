import { BrowserRouter, Route, Routes } from 'react-router-dom'
import { AuthProvider } from './auth/AuthContext'
import { Layout } from './components/Layout'
import { ProtectedRoute } from './components/ProtectedRoute'
import { AdminPage } from './pages/AdminPage'
import { LoginPage, RegisterPage } from './pages/AuthPages'
import { CartPage } from './pages/CartPage'
import { CheckoutPage } from './pages/CheckoutPage'
import { HomePage } from './pages/HomePage'
import { OrderConfirmationPage, OrderDetailPage, OrdersPage } from './pages/OrdersPage'
import { ProductDetailPage } from './pages/ProductDetailPage'
import { ProductsPage } from './pages/ProductsPage'

const protect = (page: React.ReactNode, admin = false) => <ProtectedRoute admin={admin}>{page}</ProtectedRoute>

export default function App() {
  return <BrowserRouter><AuthProvider><Routes><Route element={<Layout/>}><Route path="/" element={<HomePage/>}/><Route path="/products" element={<ProductsPage/>}/><Route path="/products/:id" element={<ProductDetailPage/>}/><Route path="/login" element={<LoginPage/>}/><Route path="/register" element={<RegisterPage/>}/><Route path="/cart" element={protect(<CartPage/>)}/><Route path="/checkout" element={protect(<CheckoutPage/>)}/><Route path="/orders" element={protect(<OrdersPage/>)}/><Route path="/orders/:id" element={protect(<OrderDetailPage/>)}/><Route path="/orders/:id/confirmed" element={protect(<OrderConfirmationPage/>)}/><Route path="/admin" element={protect(<AdminPage/>, true)}/><Route path="*" element={<div className="page-state"><h1>Page not found</h1><a href="/">Return home</a></div>}/></Route></Routes></AuthProvider></BrowserRouter>
}
