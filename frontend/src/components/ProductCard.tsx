import { Link } from 'react-router-dom'
import type { Product } from '../types'

export function ProductCard({ product }: { product: Product }) {
  return <article className="product-card">
    <Link to={`/products/${product.id}`} className="product-image-wrap">
      {product.image_url ? <img src={product.image_url} alt={product.name} className="product-image" /> : <div className="image-placeholder">SC</div>}
      {product.stock_quantity === 0 && <span className="sold-out">Sold out</span>}
    </Link>
    <div className="product-meta"><span>{product.category}</span><span>{product.stock_quantity > 0 ? 'In stock' : 'Unavailable'}</span></div>
    <Link to={`/products/${product.id}`} className="product-name">{product.name}</Link>
    <strong>£{Number(product.price).toFixed(2)}</strong>
  </article>
}
