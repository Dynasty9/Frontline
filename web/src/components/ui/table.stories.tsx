import type { Meta, StoryObj } from "@storybook/react-vite"
import {
  Table,
  TableBody,
  TableCaption,
  TableCell,
  TableFooter,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { lobbies } from "@/test/fixtures"

const meta = {
  title: "UI/Table",
  component: Table,
  render: (args) => (
    <Table {...args}>
      <TableCaption>Battles being hosted</TableCaption>
      <TableHeader>
        <TableRow>
          <TableHead>Battle</TableHead>
          <TableHead>Commander</TableHead>
          <TableHead className="text-right">Players</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {lobbies.map((l) => (
          <TableRow key={l.id}>
            <TableCell className="font-medium">{l.name}</TableCell>
            <TableCell>{l.host}</TableCell>
            <TableCell className="text-right tabular-nums">
              {l.players}/{l.max_players}
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
      <TableFooter>
        <TableRow>
          <TableCell colSpan={2}>Total</TableCell>
          <TableCell className="text-right tabular-nums">{lobbies.reduce((n, l) => n + l.players, 0)}</TableCell>
        </TableRow>
      </TableFooter>
    </Table>
  ),
} satisfies Meta<typeof Table>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {}
