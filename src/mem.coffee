exports.mem = new (->
    pack = this

    align = exports.align

    pack.PageOffset = 12
    pack.PageSize = 1 << pack.PageOffset
    pack.PageMask = pack.PageSize - 1

    pack.PageStart = (i) -> (i << pack.PageOffset)
    pack.PageId = (i) -> (i >> pack.PageOffset)

    pack.DataPage = ->
        self = this
        bytes = new ArrayBuffer(pack.PageSize)
        view = new DataView(bytes)

        self.Read = (offset) -> view.getUint8 offset
        self.Write = (offset, b) -> view.setUint8 offset, b
        self.Bytes = bytes
        return

    pack.NoopPage = ->
        self = this
        self.Read = (offset) -> 0
        self.Write = (offset, b) -> return
        return

    noopPage = new pack.NoopPage()

    pack.Align = (p) ->
        self = this
        self.page = p

        maskOffset = (offset) -> (offset & pack.PageMask)
        offset8 = (offset) -> maskOffset(offset)
        offset16 = (offset) -> align.U16(maskOffset(offset))
        offset32 = (offset) -> align.U32(maskOffset(offset))

        writeU8 = (offset, value) ->
            self.page.Write(offset, value)
            return

        writeU16 = (offset, value) ->
            self.page.Write(offset, value & 0xff)
            self.page.Write(offset + 1, (value >> 8) & 0xff)
            return

        writeU32 = (offset, value) ->
            self.page.Write(offset, value & 0xff)
            self.page.Write(offset + 1, (value >> 8) & 0xff)
            self.page.Write(offset + 2, (value >> 16) & 0xff)
            self.page.Write(offset + 3, (value >> 24) & 0xff)

        readU8 = (offset) -> self.page.Read(offset)
        readU16 = (offset) ->
            ret = self.page.Read(offset)
            ret |= self.page.Read(offset + 1) << 8
            return ret
        readU32 = (offset) ->
            ret = self.page.Read(offset)
            ret |= self.page.Read(offset + 1) << 8
            ret |= self.page.Read(offset + 2) << 16
            ret |= self.page.Read(offset + 3) << 24
            return ret
        
        self.WriteU8 = (offset, value) -> writeU8(offset8(offset), value)
        self.WriteU16 = (offset, value) -> writeU16(offset16(offset), value)
        self.WriteU32 = (offset, value) -> writeU32(offset32(offset), value)
        self.ReadU8 = (offset) -> readU8(offset8(offset))
        self.ReadU16 = (offset) -> readU16(offset16(offset))
        self.ReadU32 = (offset) -> readU32(offset32(offset))

        return

    pack.Memory = ->
        self = this
        pages = {}
        align_ = new pack.Align()
        self.NoAutoAlloc = false

        self.Get = (addr) ->
            id = pack.PageId(addr)
            if !(id of pages)
                if self.NoAutoAlloc
                    return noopPage
                p = pack.NewPage()
                pages[id] = p
                return p
            return pages[id]

        self.Valid = (addr) -> (pack.PageId(addr) of pages)
        self.Align = (addr) -> 
            align_.page = self.Get(addr)
            return align_

        self.WriteU8 = (addr, value) ->
            self.Align(addr).WriteU8(addr, value)
        self.WriteU16 = (addr, value) ->
            self.Align(addr).WriteU16(addr, value)
        self.WriteU32 = (addr, value) ->
            self.Align(addr).WriteU32(addr, value)

        self.ReadU8 = (addr) -> self.Align(addr).ReadU8(addr)
        self.ReadU16 = (addr) -> self.Align(addr).ReadU16(addr)
        self.ReadU32 = (addr) -> self.Align(addr).ReadU32(addr)

        self.Map = (addr, page) ->
            pages[pack.PageId(addr)] = page
            return

        self.Unmap = (addr) ->
            delete pages[pack.PageId(addr)]
            return
        
        return
    
    pack.NewPage = -> new pack.DataPage()
    return
)()
