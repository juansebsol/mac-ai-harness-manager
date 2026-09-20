import Image from "next/image";
import Link from "next/link";
export function Brand() {
  return <Link href="/" className="brand" aria-label="Harness Manager home"><Image src="/brand/app-icon.png" alt="" width={40} height={40} priority /><span>Harness Manager</span></Link>;
}
