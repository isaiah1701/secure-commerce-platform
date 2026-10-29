import { useEffect, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { api } from '../api/client'
import { ProductCard } from '../components/ProductCard'
import type { Product } from '../types'

const categories = ['All', 'Electronics', 'Clothing', 'Home', 'Accessories']

export function ProductsPage() {
  const [params, setParams] = useSearchParams()
  const search = params.get('search') || ''
  const category = params.get('category') || 'All'
  const queryKey = `${search}:${category}`
  const [result, setResult] = useState<{ key: string; products: Product[]; error: string }>({ key: '', products: [], error: '' })
  const loading = result.key !== queryKey
  const products = loading ? [] : result.products
  const error = loading ? '' : result.error

  useEffect(() => {
    let active = true
    const query = new URLSearchParams()
    if (search) query.set('search', search)
    if (category !== 'All') query.set('category', category)
    api<Product[]>(`/api/products?${query}`)
      .then(data => { if (active) setResult({ key: queryKey, products: data, error: '' }) })
      .catch(err => { if (active) setResult({ key: queryKey, products: [], error: err.message }) })
    return () => { active = false }
  }, [search, category, queryKey])

  const update = (key: string, value: string) => {
    const next = new URLSearchParams(params)
    if (value && value !== 'All') next.set(key, value)
    else next.delete(key)
    setParams(next)
  }
  return <div className="page section">
    <div className="catalog-title"><div><p className="eyebrow">The collection</p><h1>Useful things,<br/><em>chosen well.</em></h1></div><p>Objects selected for quality, utility, and staying power. Nothing more than you need.</p></div>
    <div className="catalog-tools"><div className="filters">{categories.map(item => <button className={category === item ? 'active' : ''} onClick={() => update('category', item)} key={item}>{item}</button>)}</div><label className="search"><span>⌕</span><input value={search} onChange={e => update('search', e.target.value)} placeholder="Search the collection"/></label></div>
    {loading ? <div className="page-state">Loading the collection…</div> : error ? <div className="alert error">{error}</div> : products.length ? <><p className="result-count">{products.length} {products.length === 1 ? 'item' : 'items'}</p><div className="product-grid catalog-grid">{products.map(product => <ProductCard product={product} key={product.id}/>)}</div></> : <div className="page-state"><h3>No products found</h3><p>Try another search or collection.</p></div>}
  </div>
}
