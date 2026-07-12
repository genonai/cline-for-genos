import { SVGProps } from "react"
import type { Environment } from "../../../src/shared/config-types"
import { getEnvironmentColor } from "../utils/environmentColors"

/**
 * GenCode brand logo (GenOS symbol) — build-time overlay replacing Cline's robot mark.
 * Signature is kept identical to upstream ClineLogoVariable so all call sites compile:
 * theme adaptation via var(--vscode-icon-foreground) and optional environment color indicator.
 */
const ClineLogoVariable = (props: SVGProps<SVGSVGElement> & { environment?: Environment }) => {
	const { environment, ...svgProps } = props
	const fillColor = environment ? getEnvironmentColor(environment) : "var(--vscode-icon-foreground)"

	return (
		<svg fill="none" height="50" viewBox="0 0 12 14" width="43" xmlns="http://www.w3.org/2000/svg" {...svgProps}>
			<path
				d="M8.51156 4.27028L9.59819 4.91074V11.9245L9.28254 12.1098L8.81995 12.3796L8.78186 12.4016L8.76735 12.409L8.3483 12.653L6.01542 14L0.00362812 10.4894V9.03054L6.02086 12.5448L8.35011 11.1978V9.83982V9.81046V9.81413V5.63744L7.26712 4.99882L8.51156 4.27212V4.27028ZM9.67438 2.13055H9.67619L9.32971 1.92686L9.30612 1.91401L9.26984 1.89199L8.74558 1.58186L8.42993 1.40018L2.42358 4.90706L2.41814 6.17879L3.66259 6.90549L3.66803 5.63744L7.24354 3.54909L7.27075 3.53624L8.43356 2.85726L10.7519 4.22441V11.2529L12 10.5243V3.49954L9.678 2.13055H9.67438ZM0.00362812 7.68725L6.00816 11.1941L7.10023 10.5629V9.10762L6.01179 9.73706L2.43628 7.64871H2.43991L2.4127 7.63403L1.24989 6.95687L1.26077 4.24276L7.278 0.728536L6.02993 0L0.0163265 3.51239L0.00362812 6.23017V6.6706L0 7.31839H0.00362812V7.68725Z"
				fill={fillColor}
			/>
		</svg>
	)
}
export default ClineLogoVariable
