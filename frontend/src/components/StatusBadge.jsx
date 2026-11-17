export default function StatusBadge({value}){return <span className={'badge '+(value||'').toLowerCase().replaceAll(' ','-')}>{value}</span>}
