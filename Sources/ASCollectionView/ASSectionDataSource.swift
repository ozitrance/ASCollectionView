// ASCollectionView. Created by Apptek Studios 2019

import Foundation
import SwiftUI

internal protocol ASSectionDataSourceProtocol
{
	func getIndexPaths(withSectionIndex sectionIndex: Int) -> [IndexPath]
	func getUniqueItemIDs<SectionID: Hashable>(withSectionID sectionID: SectionID) -> [ASCollectionViewItemUniqueID]
	func configureHostingController(reusingController: ASHostingControllerProtocol?, forItemID itemID: ASCollectionViewItemUniqueID, isSelected: Bool) -> ASHostingControllerProtocol?
	func getTypeErasedData(for indexPath: IndexPath) -> Any?
	func onAppear(_ indexPath: IndexPath)
	func onDisappear(_ indexPath: IndexPath)
	func prefetch(_ indexPaths: [IndexPath])
	func cancelPrefetch(_ indexPaths: [IndexPath])
	func getDragItem(for indexPath: IndexPath) -> UIDragItem?
	func removeItem(from indexPath: IndexPath)
	func insertDragItems(_ items: [UIDragItem], at indexPath: IndexPath)
	var dragEnabled: Bool { get }
	var dropEnabled: Bool { get }
}

public enum CellEvent<Data>
{
	/// Respond by starting necessary prefetch operations for this data to be displayed soon (eg. download images)
	case prefetchForData(data: [Data])

	/// Called when its no longer necessary to prefetch this data
	case cancelPrefetchForData(data: [Data])

	/// Called when an item is appearing on the screen
	case onAppear(item: Data)

	/// Called when an item is disappearing from the screen
	case onDisappear(item: Data)
}

public enum DragDrop<Data>
{
	case onRemoveItem(indexPath: IndexPath)
	case onAddItems(items: [Data], atIndexPath: IndexPath)
}

public typealias OnCellEvent<Data> = ((_ event: CellEvent<Data>) -> Void)
public typealias OnDragDrop<Data> = ((_ event: DragDrop<Data>) -> Void)
public typealias ItemProvider<Data> = ((_ item: Data) -> NSItemProvider)

public struct CellContext
{
	public var isSelected: Bool
	public var isFirstInSection: Bool
	public var isLastInSection: Bool
}

internal struct ASSectionDataSource<DataCollection: RandomAccessCollection, DataID, Content, Container>: ASSectionDataSourceProtocol where DataID: Hashable, Content: View, Container: View, DataCollection.Index == Int
{
	typealias Data = DataCollection.Element
	var data: DataCollection
	var dataIDKeyPath: KeyPath<Data, DataID>
	var container: ((Content) -> Container)
	var onCellEvent: OnCellEvent<Data>?
	var onDragDrop: OnDragDrop<Data>?
	var itemProvider: ItemProvider<Data>?
	var content: (Data, CellContext) -> Content

	var dragEnabled: Bool { onDragDrop != nil }
	var dropEnabled: Bool { onDragDrop != nil }

	func cellContext(forItemID itemID: ASCollectionViewItemUniqueID, isSelected: Bool) -> CellContext
	{
		CellContext(
			isSelected: isSelected,
			isFirstInSection: data.first?[keyPath: dataIDKeyPath].hashValue == itemID.itemIDHash,
			isLastInSection: data.last?[keyPath: dataIDKeyPath].hashValue == itemID.itemIDHash)
	}

	func configureHostingController(reusingController: ASHostingControllerProtocol? = nil, forItemID itemID: ASCollectionViewItemUniqueID, isSelected: Bool) -> ASHostingControllerProtocol?
	{
		guard let item = data.first(where: { $0[keyPath: dataIDKeyPath].hashValue == itemID.itemIDHash }) else { return nil }
		let view = content(item, cellContext(forItemID: itemID, isSelected: isSelected))
		let containedView = container(view)
		
		if let existingHC = reusingController as? ASHostingController<Container>
		{
			existingHC.setView(containedView)
			return existingHC
		}
		else
		{
			let newHC = ASHostingController<Container>(containedView)
			return newHC
		}
	}

	func getTypeErasedData(for indexPath: IndexPath) -> Any?
	{
		return data[safe: indexPath.item]
	}

	func getIndexPaths(withSectionIndex sectionIndex: Int) -> [IndexPath]
	{
		data.indices.map { IndexPath(item: $0, section: sectionIndex) }
	}

	func getUniqueItemIDs<SectionID: Hashable>(withSectionID sectionID: SectionID) -> [ASCollectionViewItemUniqueID]
	{
		data.map
		{
			ASCollectionViewItemUniqueID(sectionID: sectionID, itemID: $0[keyPath: dataIDKeyPath])
		}
	}

	func onAppear(_ indexPath: IndexPath)
	{
		guard let item = data[safe: indexPath.item] else { return }
		onCellEvent?(.onAppear(item: item))
	}

	func onDisappear(_ indexPath: IndexPath)
	{
		guard let item = data[safe: indexPath.item] else { return }
		onCellEvent?(.onDisappear(item: item))
	}

	func prefetch(_ indexPaths: [IndexPath])
	{
		let dataToPrefetch: [Data] = indexPaths.compactMap
		{
			return data[safe: $0.item]
		}
		onCellEvent?(.prefetchForData(data: dataToPrefetch))
	}

	func cancelPrefetch(_ indexPaths: [IndexPath])
	{
		let dataToCancelPrefetch: [Data] = indexPaths.compactMap
		{
			return data[safe: $0.item]
		}
		onCellEvent?(.cancelPrefetchForData(data: dataToCancelPrefetch))
	}

	func getDragItem(for indexPath: IndexPath) -> UIDragItem?
	{
		guard dragEnabled else { return nil }
		guard let item = data[safe: indexPath.item] else { return nil }
		
		let itemProvider: NSItemProvider = self.itemProvider?(item) ?? NSItemProvider()
		let dragItem = UIDragItem(itemProvider: itemProvider)
		dragItem.localObject = item
		return dragItem
	}

	func removeItem(from indexPath: IndexPath)
	{
		guard data.containsIndex(indexPath.item) else { return }
		onDragDrop?(.onRemoveItem(indexPath: indexPath))
	}

	func insertDragItems(_ items: [UIDragItem], at indexPath: IndexPath)
	{
		guard dropEnabled else { return }
		let index = max(data.startIndex, min(indexPath.item, data.endIndex))
		let indexPath = IndexPath(item: index, section: indexPath.section)
		let dataItems = items.compactMap
		{ (dragItem) -> Data? in
			guard let item = dragItem.localObject as? Data else { return nil }
			return item
		}
		onDragDrop?(.onAddItems(items: dataItems, atIndexPath: indexPath))
	}
}
