export type Role = 'customer' | 'admin'

export interface User {
  id: number
  email: string
  first_name: string
  last_name: string
  role: Role
  created_at: string
  last_login_at: string | null
  is_active: boolean
  failed_login_attempts?: number
  locked_until?: string | null
}

export interface Product {
  id: number
  name: string
  description: string
  category: string
  price: string
  stock_quantity: number
  image_url: string | null
  active: boolean
  created_at: string
  updated_at: string
}

export interface CartItem {
  id: number
  product_id: number
  quantity: number
  product: Product
  line_total: string
}

export interface Cart {
  id: number
  items: CartItem[]
  total: string
}

export interface OrderItem {
  id: number
  product_id: number
  product_name: string
  unit_price: string
  quantity: number
}

export interface Order {
  id: number
  user_id: number
  status: 'pending' | 'confirmed' | 'cancelled'
  total_amount: string
  created_at: string
  updated_at: string
  items: OrderItem[]
}
